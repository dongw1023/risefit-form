import AVFoundation
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class FormAnalysisViewModel: ObservableObject {
    enum State {
        case idle
        case selected(URL)
        case uploading
        case processing(FormAnalysis)
        case completed(FormAnalysis)
        case failed(String)
    }

    @Published var selectedExercise: Exercise = .deadlift
    @Published var selectedItem: PhotosPickerItem?
    @Published private(set) var state: State = .idle
    @Published private(set) var analyses: [FormAnalysis] = []
    @Published private(set) var isLoadingHistory = false
    @Published private(set) var historyError: String?

    private let api: FormAnalysisAPI
    private var pollingTask: Task<Void, Never>?

    init(authToken: String?) {
        let api = FormAnalysisAPI()
        api.authToken = authToken
        self.api = api
    }

    deinit {
        pollingTask?.cancel()
    }

    func loadSelectedVideo() async {
        guard let selectedItem else { return }

        if let pickedVideo = try? await selectedItem.loadTransferable(type: PickedVideo.self) {
            state = .selected(pickedVideo.url)
            return
        }

        if let sourceURL = try? await selectedItem.loadTransferable(type: URL.self) {
            do {
                let localURL = try copyVideoToTemporaryDirectory(sourceURL)
                state = .selected(localURL)
            } catch {
                state = .failed(error.localizedDescription)
            }
            return
        }

        state = .failed("Could not read the selected video. Try saving the clip locally from Photos, then pick it again.")
    }

    func uploadSelectedVideo() async {
        guard case .selected(let videoURL) = state else { return }
        state = .uploading

        do {
            let uploadURL = try await compressedVideoForUpload(videoURL)
            let analysis = try await api.createAnalysis(exercise: selectedExercise, videoURL: uploadURL)
            state = .processing(analysis)
            await loadHistory()
            startPolling(id: analysis.id)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func reanalyze(_ analysis: FormAnalysis) async {
        do {
            state = .processing(analysis)
            let updatedAnalysis = try await api.reanalyzeAnalysis(id: analysis.id)
            startPolling(id: updatedAnalysis.id)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func videoURL(for analysis: FormAnalysis) -> URL? {
        api.analysedVideoURL(for: analysis)
    }

    func originalVideoURL(for analysis: FormAnalysis) -> URL? {
        api.originalVideoURL(for: analysis)
    }

    func loadHistory() async {
        isLoadingHistory = true
        historyError = nil
        defer { isLoadingHistory = false }

        do {
            analyses = try await api.listAnalyses()
        } catch {
            historyError = error.localizedDescription
        }
    }

    private func startPolling(id: UUID) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    guard let self else { return }
                    let analysis = try await self.api.fetchAnalysis(id: id)
                    switch analysis.status {
                    case .queued, .processing:
                        self.state = .processing(analysis)
                        await self.loadHistory()
                    case .completed:
                        self.state = .completed(analysis)
                        await self.loadHistory()
                        return
                    case .failed:
                        self.state = .failed(analysis.error ?? "Analysis failed.")
                        await self.loadHistory()
                        return
                    }
                } catch {
                    self?.state = .failed(error.localizedDescription)
                    return
                }
            }
        }
    }

    private func copyVideoToTemporaryDirectory(_ sourceURL: URL) throws -> URL {
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        return try copyReadableVideoToTemporaryDirectory(sourceURL)
    }

    private func compressedVideoForUpload(_ sourceURL: URL) async throws -> URL {
        let fileSize = try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? NSNumber

        if let fileSize, fileSize.intValue <= VideoCompressor.maxUploadBytes {
            return sourceURL
        }

        return try await VideoCompressor.compressForUpload(sourceURL)
    }
}

private func temporaryVideoURL(for sourceURL: URL) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)
}

private func copyReadableVideoToTemporaryDirectory(_ sourceURL: URL) throws -> URL {
    let destination = temporaryVideoURL(for: sourceURL)
    if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.copyItem(at: sourceURL, to: destination)
    return destination
}

private struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            PickedVideo(url: try copyReadableVideoToTemporaryDirectory(received.file))
        }
    }
}

private enum VideoCompressor {
    static let maxUploadBytes = 24 * 1024 * 1024

    static func compressForUpload(_ sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        let preferredPresets = [
            AVAssetExportPreset1280x720,
            AVAssetExportPresetMediumQuality,
            AVAssetExportPresetLowQuality
        ].filter { compatiblePresets.contains($0) }

        for preset in preferredPresets {
            let compressedURL = try await export(asset: asset, preset: preset)
            let fileSize = try FileManager.default.attributesOfItem(atPath: compressedURL.path)[.size] as? NSNumber
            if let fileSize, fileSize.intValue <= maxUploadBytes {
                return compressedURL
            }
        }

        throw APIError.local("The video is still too large after compression. Please trim it to a shorter clip and try again.")
    }

    private static func export(asset: AVURLAsset, preset: String) async throws -> URL {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw APIError.local("Could not prepare the video for upload.")
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        exportSession.outputURL = destination
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: destination)
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? APIError.local("Video compression failed."))
                case .cancelled:
                    continuation.resume(throwing: APIError.local("Video compression was cancelled."))
                default:
                    continuation.resume(throwing: APIError.local("Video compression did not finish."))
                }
            }
        }
    }
}
