import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class FormAnalysisViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case selected(URL)
        case uploading
        case processing(FormAnalysis)
        case completed(FormAnalysis)
        case failed(String)
    }

    @Published var selectedExercise: Exercise = .deadlift
    @Published var trainingConsent: Bool {
        didSet {
            UserDefaults.standard.set(trainingConsent, forKey: Self.trainingConsentKey)
        }
    }
    @Published var selectedItem: PhotosPickerItem?
    @Published private(set) var state: State = .idle
    @Published private(set) var analyses: [FormAnalysis] = []
    @Published private(set) var isLoadingHistory = false
    @Published private(set) var historyError: String?
    @Published private(set) var userProfile: UserProfile?

    private let api: FormAnalysisAPI
    private let authAPI = AuthAPI()
    private var pollingTask: Task<Void, Never>?
    private let authToken: String?
    private static let trainingConsentKey = "formAnalysisContributorBetaAccepted"

    init(authToken: String?) {
        let api = FormAnalysisAPI()
        api.authToken = authToken
        self.api = api
        self.authToken = authToken
        self.trainingConsent = UserDefaults.standard.bool(forKey: Self.trainingConsentKey)
    }

    deinit {
        pollingTask?.cancel()
    }

    func loadUserProfile() async {
        guard let token = authToken else { return }
        do {
            userProfile = try await authAPI.fetchMe(token: token)
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }

    func loadSelectedVideo() async {
        guard let selectedItem else { return }
        state = .loading

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
        guard trainingConsent else {
            state = .failed("Join the RiseFit Contributor Beta before uploading a video for analysis.")
            return
        }
        state = .uploading

        do {
            let analysis = try await api.createAnalysis(exercise: selectedExercise, videoURL: videoURL, trainingConsent: trainingConsent)
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

    func submitFeedback(for analysis: FormAnalysis, rating: FormAnalysisFeedbackRating, note: String?) async throws {
        try await api.submitFeedback(analysisID: analysis.id, rating: rating, note: note)
    }

    func fetchLatestAnalysis(_ analysis: FormAnalysis) async throws -> FormAnalysis {
        try await api.fetchAnalysis(id: analysis.id)
    }

    func showFailure(_ message: String) {
        state = .failed(message)
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
