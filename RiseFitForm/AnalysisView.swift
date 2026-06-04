import AVKit
import Foundation
import PhotosUI
import SwiftUI
import UIKit

struct AnalysisView: View {
    @ObservedObject var viewModel: FormAnalysisViewModel
    @State private var playback: VideoPlayback?
    @State private var reportDetail: FormAnalysis?

    var body: some View {
        ZStack {
            RiseAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    UploadPanel(viewModel: viewModel)
                    stateView
                    HistoryPanel(
                        viewModel: viewModel,
                        onPlay: { analysis, kind in
                            switch kind {
                            case .original:
                                if let url = viewModel.originalVideoURL(for: analysis) {
                                    playback = VideoPlayback(title: "Original \(analysis.exercise.capitalized)", url: url)
                                }
                            case .analysed:
                                if let url = viewModel.videoURL(for: analysis) {
                                    playback = VideoPlayback(title: "Analysed \(analysis.exercise.capitalized)", url: url)
                                }
                            }
                        },
                        onOpenReport: { analysis in
                            Task {
                                do {
                                    reportDetail = try await viewModel.fetchLatestAnalysis(analysis)
                                } catch {
                                    viewModel.showFailure(error.localizedDescription)
                                }
                            }
                        }
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 100) // Space for floating tab bar
            }
        }
        .sheet(item: $playback) { playback in
            VideoPlaybackView(playback: playback)
        }
        .sheet(item: $reportDetail) { analysis in
            AnalysisReportDetailView(
                analysis: analysis,
                videoURL: viewModel.videoURL(for: analysis),
                onReanalyze: {
                    reportDetail = nil
                    Task { await viewModel.reanalyze(analysis) }
                },
                onSubmitFeedback: { rating, note in
                    try await viewModel.submitFeedback(for: analysis, rating: rating, note: note)
                }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Form Analysis Beta")
                        .riseFont(.header)
                        .foregroundStyle(Color.riseText)

                    Text("Research contributor beta")
                        .riseFont(.bodyBold)
                        .foregroundStyle(Color.riseMint.opacity(0.85))
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.riseMint.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: "waveform.path.ecg.rectangle")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.riseMint)
                }
            }

            HStack(spacing: 8) {
                CapabilityPill(index: "1", title: "Consent")
                CapabilityPill(index: "2", title: "Upload")
                CapabilityPill(index: "3", title: "Review")
            }
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch viewModel.state {
        case .idle:
            GuidancePanel()
        case .loading:
            EmptyView()
        case .selected:
            EmptyView()
        case .uploading:
            ProgressPanel(title: "Uploading video", message: "Uploading your beta contributor clip for form analysis.")
        case .processing:
            ProgressPanel(title: "Analysing Form", message: "The beta model is identifying joints and form events...")
        case .completed(let analysis):
            AnalysisResultView(analysis: analysis, videoURL: viewModel.videoURL(for: analysis)) {
                Task { await viewModel.reanalyze(analysis) }
            } onSubmitFeedback: { rating, note in
                try await viewModel.submitFeedback(for: analysis, rating: rating, note: note)
            }
        case .failed(let message):
            FailurePanel(message: message)
        }
    }
}

private enum HistoryVideoKind {
    case original
    case analysed
}

private struct VideoPlayback: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

private struct CapabilityPill: View {
    let index: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(index)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Color.black)
                .frame(width: 19, height: 19)
                .background(Color.riseMint)
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(Color.riseText.opacity(0.82))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.riseText.opacity(0.06))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.riseText.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct UploadPanel: View {
    @ObservedObject var viewModel: FormAnalysisViewModel
    @State private var previewPlayback: VideoPlayback?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contributor beta")
                        .riseFont(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.riseMint)

                    Text(uploadTitle)
                        .riseFont(.title)
                        .foregroundStyle(Color.riseText)

                    Text("RiseFit is still learning from real lifting videos. Beta analysis may be inaccurate and is not medical, safety, or professional coaching advice.")
                        .riseFont(.bodyMedium)
                        .foregroundStyle(Color.riseText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: uploadIcon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.riseMint)
                    .frame(width: 56, height: 56)
                    .background(Color.riseSoftFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 12) {
                StepLabel(number: "1", title: "Choose movement")
                exercisePicker
            }

            VStack(alignment: .leading, spacing: 12) {
                StepLabel(number: "2", title: "Add training clip")

                if !hasSelectedVideo {
                    videoPickerButton(title: "Choose Video", icon: "plus.circle.fill")
                }

                uploadStateContent
            }

            VStack(alignment: .leading, spacing: 12) {
                StepLabel(number: "3", title: "Join contributor beta")

                Toggle(isOn: $viewModel.trainingConsent) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("I agree and join the beta")
                            .riseFont(.bodyBold)
                            .foregroundStyle(Color.riseText)

                        Text("I allow RiseFit to use my uploaded exercise videos, cropped frames, pose keypoints, movement labels, predictions, analysis results, and related derived movement data to improve form-analysis models.")
                            .riseFont(.caption)
                            .foregroundStyle(Color.riseText.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.riseMint)
                .padding(14)
                .background(Color.riseSoftFill.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.riseText.opacity(0.08), lineWidth: 1)
                )

                Text("This beta is currently available only to users who choose to participate in the Contributor Program.")
                    .riseFont(.caption)
                    .foregroundStyle(Color.riseText.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)

                analyzeActionContent
            }
        }
        .risePanel()
        .sheet(item: $previewPlayback) { playback in
            VideoPlaybackView(playback: playback)
        }
    }

    @ViewBuilder
    private var uploadStateContent: some View {
        switch viewModel.state {
        case .loading:
            InlineProgressPanel(title: "Preparing video", message: "Copying your clip from Photos...")
        case .selected(let videoURL):
            ReadyPanel(
                videoURL: videoURL,
                changeButton: {
                    videoPickerButton(title: "Change", icon: "arrow.triangle.2.circlepath.circle.fill")
                },
                onPreview: {
                    previewPlayback = VideoPlayback(title: "Review your clip", url: videoURL)
                }
            )
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var analyzeActionContent: some View {
        if case .selected = viewModel.state {
            if !viewModel.trainingConsent {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.riseWarning)
                    Text("Join the Contributor Beta before uploading. This beta requires permission to use submitted videos and derived movement data for model improvement.")
                        .riseFont(.caption)
                        .foregroundStyle(Color.riseText.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Color.riseWarning.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                Task { await viewModel.uploadSelectedVideo() }
            } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Analyze Beta Clip")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .riseMainButton()
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.trainingConsent)
            .opacity(viewModel.trainingConsent ? 1 : 0.45)
        }
    }

    private var exercisePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Exercise.allCases) { exercise in
                    ExerciseChip(
                        title: exercise.title,
                        isSelected: viewModel.selectedExercise == exercise
                    ) {
                        viewModel.selectedExercise = exercise
                    }
                }
            }
        }
    }

    private var hasSelectedVideo: Bool {
        if case .selected = viewModel.state {
            return true
        }
        return false
    }

    private var uploadTitle: String {
        if case .selected = viewModel.state {
            return "Clip ready"
        }
        return "Pick a lift video"
    }

    private var uploadIcon: String {
        if case .selected = viewModel.state {
            return "checkmark"
        }
        return "video.badge.plus"
    }

    private func videoPickerButton(title: String, icon: String) -> some View {
        PhotosPicker(selection: $viewModel.selectedItem, matching: .videos) {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
            }
            .riseMainButton()
        }
        .buttonStyle(.plain)
        .onChange(of: viewModel.selectedItem) { _ in
            Task { await viewModel.loadSelectedVideo() }
        }
    }
}

private struct StepLabel: View {
    let number: String
    let title: String

    var body: some View {
        HStack(spacing: 9) {
            Text(number)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Color.black)
                .frame(width: 22, height: 22)
                .background(Color.riseMint)
                .clipShape(Circle())

            Text(title)
                .riseFont(.caption)
                .textCase(.uppercase)
                .foregroundStyle(Color.riseText.opacity(0.54))
        }
    }
}

private struct ExerciseChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isSelected ? Color.white : Color.riseSecondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(isSelected ? Color.riseMint : Color.riseSoftFill)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.riseText.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct GuidancePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Capture Checklist")
                .riseFont(.subtitle)
                .foregroundStyle(Color.riseText)

            ChecklistRow(icon: "person.crop.rectangle", text: "Keep the full body in frame")
            ChecklistRow(icon: "camera.metering.center.weighted", text: "Use a stable side angle")
            ChecklistRow(icon: "light.max", text: "Avoid dark or backlit clips")
        }
        .risePanel()
    }
}

private struct HistoryPanel: View {
    @ObservedObject var viewModel: FormAnalysisViewModel
    let onPlay: (FormAnalysis, HistoryVideoKind) -> Void
    let onOpenReport: (FormAnalysis) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uploaded Videos")
                        .riseFont(.subtitle)
                        .foregroundStyle(Color.riseText)

                    Text("Your recent form checks")
                        .riseFont(.bodyMedium)
                        .foregroundStyle(Color.riseText.opacity(0.50))
                }

                Spacer()

                Button {
                    Task { await viewModel.loadHistory() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.riseMint)
                        .frame(width: 38, height: 38)
                        .background(Color.riseSoftFill)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            if viewModel.isLoadingHistory && viewModel.analyses.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.riseMint)
                    Text("Loading videos")
                        .riseFont(.bodyBold)
                        .foregroundStyle(Color.riseText.opacity(0.66))
                }
            } else if let historyError = viewModel.historyError {
                Text(historyError)
                    .riseFont(.bodyMedium)
                    .foregroundStyle(Color.riseError)
                    .fixedSize(horizontal: false, vertical: true)
            } else if viewModel.analyses.isEmpty {
                Text("No uploaded videos yet.")
                    .riseFont(.bodyMedium)
                    .foregroundStyle(Color.riseText.opacity(0.60))
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.analyses) { analysis in
                        HistoryRow(
                            analysis: analysis,
                            thumbnailURL: viewModel.originalVideoURL(for: analysis),
                            onPlay: onPlay,
                            onOpenReport: onOpenReport
                        ) { analysis in
                            Task { await viewModel.reanalyze(analysis) }
                        }
                    }
                }
            }
        }
        .risePanel()
    }
}

private struct HistoryRow: View {
    let analysis: FormAnalysis
    let thumbnailURL: URL?
    let onPlay: (FormAnalysis, HistoryVideoKind) -> Void
    let onOpenReport: (FormAnalysis) -> Void
    let onReanalyze: (FormAnalysis) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VideoThumbnailView(url: thumbnailURL, fallbackIcon: icon)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(analysis.exercise.replacingOccurrences(of: "_", with: " ").capitalized)
                            .riseFont(.bodyBold)
                            .foregroundStyle(Color.riseText)

                        statusBadge
                    }

                    Text(analysis.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .riseFont(.caption)
                        .foregroundStyle(Color.riseText.opacity(0.4))
                }

                Spacer()

                if let score = analysis.formScore.map(Double.init) ?? analysis.report?.formScore {
                    Text("\(Int(score))")
                        .riseFont(.header)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.riseMint)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                VideoActionButton(title: "Original", icon: "play.rectangle.fill") {
                    onPlay(analysis, .original)
                }

                VideoActionButton(title: "Report", icon: "doc.text.magnifyingglass") {
                    onOpenReport(analysis)
                }
                .disabled(analysis.status != .completed || analysis.report == nil)
                .opacity(analysis.status == .completed && analysis.report != nil ? 1 : 0.45)

                VideoActionButton(title: "Re-analyse", icon: "arrow.clockwise.circle") {
                    onReanalyze(analysis)
                }
                .disabled(analysis.status == .processing || analysis.status == .queued)
                .opacity(analysis.status == .processing || analysis.status == .queued ? 0.45 : 1)
            }
        }
        .padding(14)
        .background(Color.riseSoftFill.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var icon: String {
        switch analysis.exercise.lowercased() {
        case "deadlift":
            return "figure.strengthtraining.traditional"
        case "squat":
            return "figure.strengthtraining.functional"
        default:
            return "figure.run"
        }
    }

    private var statusBadge: some View {
        Text(analysis.status.rawValue.capitalized)
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch analysis.status {
        case .completed:
            return Color.riseMint
        case .failed:
            return Color.riseError
        case .queued, .processing:
            return Color.riseWarning
        }
    }
}

private struct VideoThumbnailView: View {
    let url: URL?
    let fallbackIcon: String
    var size: CGFloat = 74
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.riseMint.opacity(0.12)

                Image(systemName: fallbackIcon)
                    .font(.system(size: size * 0.24, weight: .bold))
                    .foregroundStyle(Color.riseMint)
            }

            VStack {
                Spacer()
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(Color.black)
                        .frame(width: size * 0.24, height: size * 0.24)
                        .background(Color.riseMint)
                        .clipShape(Circle())
                    Spacer()
                }
                .padding(size * 0.09)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.riseText.opacity(0.08), lineWidth: 1)
        )
        .task(id: url) {
            thumbnail = nil
            guard let url else { return }
            thumbnail = await makeVideoThumbnail(url)
        }
    }
}

private func makeVideoThumbnail(_ url: URL) async -> UIImage? {
    await Task.detached(priority: .utility) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)

        do {
            let image = try generator.copyCGImage(at: CMTime(seconds: 0.6, preferredTimescale: 600), actualTime: nil)
            return UIImage(cgImage: image)
        } catch {
            return nil
        }
    }.value
}

private struct VideoActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(Color.riseText.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.riseText.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.riseText.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct VideoPlaybackView: View {
    @Environment(\.dismiss) private var dismiss
    let playback: VideoPlayback
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            RiseAppBackground()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(playback.title)
                        .riseFont(.title)
                        .foregroundStyle(Color.riseText)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.riseText)
                            .frame(width: 40, height: 40)
                            .background(Color.riseText.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.riseText.opacity(0.1), lineWidth: 1)
                    )
            }
            .padding(24)
        }
        .onAppear {
            let player = AVPlayer(url: playback.url)
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

private struct AnalysisReportDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let analysis: FormAnalysis
    let videoURL: URL?
    let onReanalyze: () -> Void
    let onSubmitFeedback: (FormAnalysisFeedbackRating, String?) async throws -> Void

    var body: some View {
        ZStack {
            RiseAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Beta Report")
                                .riseFont(.caption)
                                .textCase(.uppercase)
                                .foregroundStyle(Color.riseMint)

                            Text(analysis.exercise.replacingOccurrences(of: "_", with: " ").capitalized)
                                .riseFont(.title)
                                .foregroundStyle(Color.riseText)

                            Text(analysis.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .riseFont(.bodyMedium)
                                .foregroundStyle(Color.riseText.opacity(0.54))
                        }

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.riseText)
                                .frame(width: 40, height: 40)
                                .background(Color.riseText.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    AnalysisResultView(
                        analysis: analysis,
                        videoURL: videoURL,
                        onReanalyze: onReanalyze,
                        onSubmitFeedback: onSubmitFeedback
                    )
                }
                .padding(24)
                .padding(.bottom, 32)
            }
        }
    }
}

private struct ChecklistRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.riseMint)
                .frame(width: 32, height: 32)
                .background(Color.riseMint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(text)
                .riseFont(.bodyMedium)
                .foregroundStyle(Color.riseText.opacity(0.8))
        }
    }
}

private struct ReadyPanel<ChangeButton: View>: View {
    let videoURL: URL
    @ViewBuilder let changeButton: () -> ChangeButton
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review your clip")
                        .riseFont(.subtitle)
                        .foregroundStyle(Color.riseText)

                    Text("Make sure the full lift is visible before sending it to the beta model.")
                        .riseFont(.bodyMedium)
                        .foregroundStyle(Color.riseText.opacity(0.62))
                }

                VideoPreviewCard(
                    url: videoURL,
                    title: "Selected clip",
                    fallbackIcon: "video.fill",
                    onPreview: onPreview
                )

                HStack(spacing: 10) {
                    changeButton()

                    Button(action: onPreview) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Preview")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .riseMainButton()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.riseSoftFill.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.riseLine, lineWidth: 1)
        )
    }
}

private struct InlineProgressPanel: View {
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Color.riseMint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .riseFont(.bodyBold)
                    .foregroundStyle(Color.riseText)
                Text(message)
                    .riseFont(.bodyMedium)
                    .foregroundStyle(Color.riseText.opacity(0.62))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.riseSoftFill.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.riseLine, lineWidth: 1)
        )
    }
}

private struct VideoPreviewCard: View {
    let url: URL
    let title: String
    let fallbackIcon: String
    let onPreview: () -> Void
    @State private var metadata: LocalVideoMetadata?

    var body: some View {
        Button(action: onPreview) {
            HStack(spacing: 14) {
                VideoThumbnailView(url: url, fallbackIcon: fallbackIcon, size: 96)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Clip ready")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.riseMint)
                    .clipShape(Capsule())

                    Text(title)
                        .riseFont(.bodyBold)
                        .foregroundStyle(Color.riseText)

                    Text(metadata?.summary ?? "Preparing clip details")
                        .riseFont(.caption)
                        .foregroundStyle(Color.riseText.opacity(0.52))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.black)
                    .frame(width: 36, height: 36)
                    .background(Color.riseMint)
                    .clipShape(Circle())
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.riseSoftFill.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.riseText.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .task(id: url) {
            metadata = await LocalVideoMetadata.load(from: url)
        }
    }
}

private struct LocalVideoMetadata {
    let duration: TimeInterval?
    let fileSize: Int64?

    var summary: String {
        [durationText, fileSizeText].compactMap(\.self).joined(separator: " · ")
    }

    private var durationText: String? {
        guard let duration, duration.isFinite, duration > 0 else { return nil }
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
    }

    private var fileSizeText: String? {
        guard let fileSize, fileSize > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    static func load(from url: URL) async -> LocalVideoMetadata {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            let duration = try? await asset.load(.duration)
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            return LocalVideoMetadata(duration: duration.map(CMTimeGetSeconds), fileSize: values?.fileSize.map(Int64.init))
        }.value
    }
}

private struct ProcessingStageRow: View {
    let icon: String
    let title: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isActive ? Color.black : Color.riseMint)
                .frame(width: 26, height: 26)
                .background(isActive ? Color.riseMint : Color.riseMint.opacity(0.10))
                .clipShape(Circle())

            Text(title)
                .riseFont(.caption)
                .foregroundStyle(Color.riseText.opacity(isActive ? 0.82 : 0.48))

            Spacer()
        }
    }
}

private struct ProgressPanel: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                ProgressView()
                    .tint(Color.riseMint)
                    .controlSize(.large)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .riseFont(.subtitle)
                        .foregroundStyle(Color.riseText)
                    Text(message)
                        .riseFont(.bodyMedium)
                        .foregroundStyle(Color.riseText.opacity(0.62))
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.riseText.opacity(0.06))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.riseMint)
                        .frame(width: proxy.size.width * 0.55)
                        .shadow(color: Color.riseMint.opacity(0.5), radius: 4)
                }
            }
            .frame(height: 10)

            VStack(spacing: 10) {
                ProcessingStageRow(icon: "film.fill", title: "Preparing video", isActive: title.contains("Preparing"))
                ProcessingStageRow(icon: "arrow.up.circle.fill", title: "Uploading clip", isActive: title.contains("Uploading"))
                ProcessingStageRow(icon: "waveform.path.ecg", title: "Reading movement", isActive: title.contains("Analysing"))
            }
            .padding(14)
            .background(Color.riseSoftFill.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .risePanel()
    }
}

private struct FailurePanel: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.riseError)
            Text("Analysis failed")
                .riseFont(.subtitle)
                .foregroundStyle(Color.riseText)
            Text(message)
                .riseFont(.bodyMedium)
                .foregroundStyle(Color.riseText.opacity(0.65))
        }
        .risePanel()
    }
}

private struct AnalysisResultView: View {
    let analysis: FormAnalysis
    let videoURL: URL?
    let onReanalyze: () -> Void
    let onSubmitFeedback: (FormAnalysisFeedbackRating, String?) async throws -> Void
    @State private var playback: VideoPlayback?
    @State private var selectedFeedback: FormAnalysisFeedbackRating?
    @State private var feedbackNote = ""
    @State private var feedbackMessage: String?
    @State private var isSubmittingFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            BetaResultNoticePanel()

            if let videoURL {
                VideoPreviewCard(
                    url: videoURL,
                    title: "Analysed clip",
                    fallbackIcon: "waveform.path.ecg.rectangle",
                    onPreview: {
                        playback = VideoPlayback(
                            title: "Analysed \(analysis.exercise.replacingOccurrences(of: "_", with: " ").capitalized)",
                            url: videoURL
                        )
                    }
                )
            }

            if let report = analysis.report {
                ScorePanel(report: report)
                CaptureQualityPanel(report: report)

                if let reps = report.reps, !reps.isEmpty {
                    RepDetailsPanel(reps: reps)
                }

                if let events = report.detectedEvents, !events.isEmpty {
                    EventsPanel(events: events)
                } else {
                    CleanLiftPanel()
                }
            }

            FeedbackPromptPanel(
                selectedFeedback: selectedFeedback,
                note: $feedbackNote,
                message: feedbackMessage,
                isSubmitting: isSubmittingFeedback
            ) { rating in
                Task {
                    await submitFeedback(rating)
                }
            }

            Button(action: onReanalyze) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Re-run Analysis")
                        .riseFont(.bodyBold)
                    Spacer()
                }
                .foregroundStyle(Color.riseText.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color.riseText.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.riseText.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(item: $playback) { playback in
            VideoPlaybackView(playback: playback)
        }
    }

    private func submitFeedback(_ rating: FormAnalysisFeedbackRating) async {
        isSubmittingFeedback = true
        feedbackMessage = nil
        do {
            let trimmedNote = feedbackNote.trimmingCharacters(in: .whitespacesAndNewlines)
            try await onSubmitFeedback(rating, trimmedNote.isEmpty ? nil : trimmedNote)
            selectedFeedback = rating
            feedbackMessage = "Thanks. Your feedback was recorded."
        } catch {
            feedbackMessage = error.localizedDescription
        }
        isSubmittingFeedback = false
    }
}

private struct BetaResultNoticePanel: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "testtube.2")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.riseMint)
                .frame(width: 34, height: 34)
                .background(Color.riseMint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Text("Beta result")
                    .riseFont(.bodyBold)
                    .foregroundStyle(Color.riseText)
                Text("This analysis may be inaccurate. Use it for testing RiseFit only, not as medical, safety, or professional coaching advice.")
                    .riseFont(.caption)
                    .foregroundStyle(Color.riseText.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .risePanel(padding: 16)
    }
}

private struct FeedbackPromptPanel: View {
    let selectedFeedback: FormAnalysisFeedbackRating?
    @Binding var note: String
    let message: String?
    let isSubmitting: Bool
    let onSelect: (FormAnalysisFeedbackRating) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Was this beta result right?")
                    .riseFont(.subtitle)
                    .foregroundStyle(Color.riseText)
                Text("Your answer helps us find labeling and model mistakes faster.")
                    .riseFont(.bodyMedium)
                    .foregroundStyle(Color.riseText.opacity(0.58))
            }

            HStack(spacing: 10) {
                ForEach(FormAnalysisFeedbackRating.allCases) { rating in
                    Button {
                        onSelect(rating)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: rating.icon)
                                .font(.system(size: 16, weight: .bold))
                            Text(rating.title)
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(selectedFeedback == rating ? Color.black : Color.riseText.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedFeedback == rating ? Color.riseMint : Color.riseText.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                    .opacity(isSubmitting ? 0.55 : 1)
                }
            }

            TextField("Optional note, e.g. rep count was wrong", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.riseText)
                .padding(12)
                .background(Color.riseText.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(isSubmitting)

            if let message {
                Text(message)
                    .riseFont(.caption)
                    .foregroundStyle(message.hasPrefix("Thanks") ? Color.riseMint : Color.riseError)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .risePanel()
    }
}

private struct ScorePanel: View {
    let report: FormAnalysisReport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Form Report")
                        .riseFont(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.riseMint)

                    Text(report.exercise?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Lift")
                        .riseFont(.title)
                        .foregroundStyle(Color.riseText)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.riseText.opacity(0.06), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max((report.formScore ?? 0) / 100, 0), 1)))
                        .stroke(Color.riseMint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Color.riseMint.opacity(0.3), radius: 6)
                    Text(report.formGrade ?? "-")
                        .riseFont(.header)
                        .font(.system(size: 30))
                        .foregroundStyle(Color.riseText)
                }
                .frame(width: 90, height: 88)
            }

            HStack(spacing: 12) {
                MetricTile(title: "Score", value: report.formScore.map { "\(Int($0))" } ?? "-")
                MetricTile(title: "Reps", value: report.repCount.map { "\($0)" } ?? report.summary?.repCount.map { "\($0)" } ?? "-")
                MetricTile(title: "Issues", value: report.issueCount.map { "\($0)" } ?? report.summary?.issueCount.map { "\($0)" } ?? "-")
            }

            HStack(spacing: 12) {
                MetricTile(title: "View", value: report.viewHealth.map { "\(Int($0))%" } ?? "-")
                MetricTile(title: "Quality", value: (report.analysisQuality ?? report.summary?.analysisQuality ?? "-").capitalized)
                MetricTile(title: "Confidence", value: formatPercent(report.confidence ?? report.summary?.confidence))
            }

            HStack(spacing: 12) {
                MetricTile(title: "Duration", value: report.totalDuration.map { formatSeconds($0) } ?? "-")
                MetricTile(title: "Processed", value: report.video?.processedFrameCount.map { "\($0) frames" } ?? "-")
                MetricTile(title: "FPS", value: report.video?.processedFPS.map { String(format: "%.0f", $0) } ?? "-")
            }

            if let primaryIssue = report.primaryIssue ?? report.summary?.primaryIssue {
                Text("Primary issue: \(primaryIssue.replacingOccurrences(of: "_", with: " ").capitalized)")
                    .riseFont(.bodyMedium)
                    .foregroundStyle(Color.riseText.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .risePanel()
    }
}

private struct CaptureQualityPanel: View {
    let report: FormAnalysisReport

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Capture quality")
                        .riseFont(.bodyBold)
                        .foregroundStyle(Color.riseText)
                    Spacer()
                    Text(report.viewHealth.map { "\(Int($0))%" } ?? "-")
                        .riseFont(.caption)
                        .foregroundStyle(color)
                }

                Text(message)
                    .riseFont(.caption)
                    .foregroundStyle(Color.riseText.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .risePanel(padding: 16)
    }

    private var score: Double? {
        report.viewHealth
    }

    private var color: Color {
        guard let score else { return Color.riseWarning }
        if score >= 80 { return Color.riseMint }
        if score >= 55 { return Color.riseWarning }
        return Color.riseError
    }

    private var icon: String {
        guard let score else { return "camera.metering.unknown" }
        return score >= 80 ? "camera.viewfinder" : "camera.metering.center.weighted"
    }

    private var message: String {
        guard let score else {
            return "The beta model did not report a view score for this clip."
        }
        if score >= 80 {
            return "The view looks usable for beta analysis."
        }
        if score >= 55 {
            return "The clip may still work, but a clear side angle with full body and bar visible is better."
        }
        return "This clip may be hard to analyze. Retake from a stable side angle with the full lift in frame."
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .riseFont(.title)
                .font(.system(size: 24))
                .foregroundStyle(Color.riseText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .riseFont(.caption)
                .foregroundStyle(Color.riseText.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.riseSoftFill.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct RepDetailsPanel: View {
    let reps: [FormRep]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rep Details")
                    .riseFont(.subtitle)
                    .foregroundStyle(Color.riseText)
                Text("Timing, tempo, and issues detected for each rep.")
                    .riseFont(.bodyMedium)
                    .foregroundStyle(Color.riseText.opacity(0.58))
            }

            VStack(spacing: 12) {
                ForEach(reps) { rep in
                    RepDetailRow(rep: rep)
                }
            }
        }
        .risePanel()
    }
}

private struct RepDetailRow: View {
    let rep: FormRep

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Rep \(rep.repIndex)")
                    .riseFont(.bodyBold)
                    .foregroundStyle(Color.riseText)

                Spacer()

                Text(timeRange)
                    .riseFont(.caption)
                    .foregroundStyle(Color.riseText.opacity(0.50))
            }

            HStack(spacing: 10) {
                RepMetric(title: "Duration", value: rep.durationSeconds.map { formatSeconds($0) } ?? "-")
                RepMetric(title: "Down", value: rep.tempo?.eccentric.map { formatSeconds($0) } ?? "-")
                RepMetric(title: "Pause", value: rep.tempo?.pause.map { formatSeconds($0) } ?? "-")
                RepMetric(title: "Up", value: rep.tempo?.concentric.map { formatSeconds($0) } ?? "-")
            }

            if let issues = rep.issues, !issues.isEmpty {
                FlowTagRow(values: issues.map(formatIssueLabel))
            } else {
                FlowTagRow(values: ["No issues"])
            }
        }
        .padding(14)
        .background(Color.riseSoftFill.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var timeRange: String {
        if let start = rep.startTime, let end = rep.endTime {
            return "\(formatSeconds(start)) - \(formatSeconds(end))"
        }
        if let start = rep.startTime {
            return "Starts \(formatSeconds(start))"
        }
        return "Timing unavailable"
    }
}

private struct RepMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.riseText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.riseText.opacity(0.44))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FlowTagRow: View {
    let values: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(values, id: \.self) { value in
                Text(value)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(value == "No issues" ? Color.riseMint : Color.riseWarning)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background((value == "No issues" ? Color.riseMint : Color.riseWarning).opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct EventsPanel: View {
    let events: [DetectedFormEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coach Notes")
                .riseFont(.subtitle)
                .foregroundStyle(Color.riseText)

            ForEach(events) { event in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "target")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.riseMint)
                        .frame(width: 34, height: 34)
                        .background(Color.riseMint.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(event.type?.replacingOccurrences(of: "_", with: " ").capitalized ?? event.error)
                                .riseFont(.bodyBold)
                                .foregroundStyle(Color.riseText)
                            Spacer()
                            if let startTime = event.startTime {
                                Text("\(startTime, specifier: "%.1f")s")
                                    .riseFont(.caption)
                                    .foregroundStyle(Color.riseText.opacity(0.4))
                            }
                        }

                        if let coachNote = event.coachNote {
                            Text(coachNote)
                                .riseFont(.bodyMedium)
                                .foregroundStyle(Color.riseText.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: 8) {
                            if let repIndex = event.repIndex {
                                EventTag(text: "Rep \(repIndex)")
                            }
                            if let severity = event.severity {
                                EventTag(text: severity.capitalized)
                            }
                            if let confidence = event.confidence {
                                EventTag(text: "\(Int(confidence * 100))%")
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.riseSoftFill.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .risePanel()
    }
}

private struct EventTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.riseMint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.riseMint.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct CleanLiftPanel: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.riseMint)
            VStack(alignment: .leading, spacing: 6) {
                Text("No major form events detected")
                    .riseFont(.subtitle)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.riseText)
                Text("Replay the analysed video to inspect your bar path and positions.")
                    .riseFont(.bodyMedium)
                    .foregroundStyle(Color.riseText.opacity(0.62))
            }
        }
        .panelStyle()
    }
}

private func formatSeconds(_ seconds: Double) -> String {
    if seconds >= 10 {
        return "\(Int(seconds))s"
    }
    return String(format: "%.1fs", seconds)
}

private func formatPercent(_ value: Double?) -> String {
    guard let value else { return "-" }
    let percent = value <= 1 ? value * 100 : value
    return "\(Int(percent.rounded()))%"
}

private func formatIssueLabel(_ value: String) -> String {
    value
        .replacingOccurrences(of: "_", with: " ")
        .split(separator: " ")
        .map { $0.capitalized }
        .joined(separator: " ")
}

private extension View {
    func panelStyle() -> some View {
        self
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.riseText.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.riseText.opacity(0.08), lineWidth: 1)
            )
    }
}
