import Foundation
import PhotosUI
import SwiftUI

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

    private let api = FormAnalysisAPI()
    private var pollingTask: Task<Void, Never>?

    deinit {
        pollingTask?.cancel()
    }

    func loadSelectedVideo() async {
        guard let selectedItem else { return }

        do {
            guard let sourceURL = try await selectedItem.loadTransferable(type: URL.self) else {
                state = .failed("Could not read the selected video.")
                return
            }
            let localURL = try copyVideoToTemporaryDirectory(sourceURL)
            state = .selected(localURL)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func uploadSelectedVideo() async {
        guard case .selected(let videoURL) = state else { return }
        state = .uploading

        do {
            let analysis = try await api.createAnalysis(exercise: selectedExercise, videoURL: videoURL)
            state = .processing(analysis)
            startPolling(id: analysis.id)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func videoURL(for analysis: FormAnalysis) -> URL? {
        api.analysedVideoURL(for: analysis)
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
                    case .completed:
                        self.state = .completed(analysis)
                        return
                    case .failed:
                        self.state = .failed(analysis.error ?? "Analysis failed.")
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

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension.isEmpty ? "mp4" : sourceURL.pathExtension)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }
}

