import AVKit
import PhotosUI
import SwiftUI

struct AnalysisView: View {
    @ObservedObject var viewModel: FormAnalysisViewModel
    @State private var playback: VideoPlayback?

    var body: some View {
        ZStack {
            RiseAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    UploadPanel(viewModel: viewModel)
                    stateView
                    HistoryPanel(viewModel: viewModel) { analysis, kind in
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
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 100) // Space for floating tab bar
            }
        }
        .sheet(item: $playback) { playback in
            VideoPlaybackView(playback: playback)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Form Analysis")
                        .riseFont(.header)
                        .foregroundStyle(Color.riseText)

                    Text("Precision lifting tracking")
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
                CapabilityPill(index: "1", title: "Pick")
                CapabilityPill(index: "2", title: "Preview")
                CapabilityPill(index: "3", title: "Analyse")
            }
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch viewModel.state {
        case .idle:
            GuidancePanel()
        case .loading:
            ProgressPanel(title: "Preparing video", message: "Copying your clip from Photos...")
        case .selected(let videoURL):
            ReadyPanel(videoURL: videoURL) {
                Task { await viewModel.uploadSelectedVideo() }
            }
        case .uploading:
            ProgressPanel(title: "Uploading video", message: "Uploading the original clip for form analysis.")
        case .processing:
            ProgressPanel(title: "Analysing Form", message: "AI is identifying joints and form events...")
        case .completed(let analysis):
            AnalysisResultView(analysis: analysis, videoURL: viewModel.videoURL(for: analysis)) {
                Task { await viewModel.reanalyze(analysis) }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training clip")
                        .riseFont(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.riseMint)

                    Text(uploadTitle)
                        .riseFont(.title)
                        .foregroundStyle(Color.riseText)

                    Text("Best results come from a side view with your full body and bar visible.")
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

                PhotosPicker(selection: $viewModel.selectedItem, matching: .videos) {
                    HStack {
                        Image(systemName: hasSelectedVideo ? "arrow.triangle.2.circlepath.circle.fill" : "plus.circle.fill")
                        Text(hasSelectedVideo ? "Change Video" : "Choose Video")
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
        .risePanel()
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
                        HistoryRow(analysis: analysis, onPlay: onPlay) { analysis in
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
    let onPlay: (FormAnalysis, HistoryVideoKind) -> Void
    let onReanalyze: (FormAnalysis) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.riseMint)
                    .frame(width: 36, height: 36)
                    .background(Color.riseMint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

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

                if let score = analysis.report?.formScore {
                    Text("\(Int(score))")
                        .riseFont(.header)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.riseMint)
                }
            }

            HStack(spacing: 10) {
                VideoActionButton(title: "Original", icon: "play.rectangle.fill") {
                    onPlay(analysis, .original)
                }

                VideoActionButton(title: "Re-analyse", icon: "arrow.clockwise.circle") {
                    onReanalyze(analysis)
                }
                .disabled(analysis.status == .processing || analysis.status == .queued)
                .opacity(analysis.status == .processing || analysis.status == .queued ? 0.45 : 1)

                VideoActionButton(title: "Analysed", icon: "waveform.path.ecg") {
                    onPlay(analysis, .analysed)
                }
                .disabled(analysis.status != .completed || analysis.analysedVideoURL == nil)
                .opacity(analysis.status == .completed && analysis.analysedVideoURL != nil ? 1 : 0.45)
            }
        }
        .padding(14)
        .background(Color.riseSoftFill.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var icon: String {
        switch Exercise(rawValue: analysis.exercise.lowercased()) {
        case .deadlift: return "figure.strengthtraining.traditional"
        case .squat: return "figure.strengthtraining.functional"
        case .benchPress: return "figure.arms.open"
        case .latPullDown: return "figure.mindful.stretching"
        case .bicepCurl: return "figure.strengthtraining.traditional"
        default: return "figure.run"
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

                VideoPlayer(player: AVPlayer(url: playback.url))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.riseText.opacity(0.1), lineWidth: 1)
                    )
            }
            .padding(24)
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

private struct ReadyPanel: View {
    let videoURL: URL
    let onAnalyze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepLabel(number: "3", title: "Preview and analyse")

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review your clip")
                        .riseFont(.subtitle)
                        .foregroundStyle(Color.riseText)

                    Text("Make sure the full lift is visible before sending it for analysis.")
                        .riseFont(.bodyMedium)
                        .foregroundStyle(Color.riseText.opacity(0.62))
                }

                SelectedVideoPreview(url: videoURL)
            }

            Button(action: onAnalyze) {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Analyze Form")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .riseMainButton()
            }
            .buttonStyle(.plain)
        }
        .risePanel()
    }
}

private struct SelectedVideoPreview: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topLeading) {
            VideoPlayer(player: player)
                .frame(height: 260)
                .background(Color.riseSoftFill)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.riseText.opacity(0.10), lineWidth: 1)
                )

            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Clip ready")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Color.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.riseMint)
            .clipShape(Capsule())
            .padding(12)
        }
        .onAppear {
            if player == nil {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear {
            player?.pause()
        }
        .onChange(of: url) { newURL in
            player?.pause()
            player = AVPlayer(url: newURL)
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.riseText.opacity(0.1), lineWidth: 1)
                    )
            }

            if let report = analysis.report {
                ScorePanel(report: report)

                if let events = report.detectedEvents, !events.isEmpty {
                    EventsPanel(events: events)
                } else {
                    CleanLiftPanel()
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
                MetricTile(title: "View", value: report.viewHealth.map { "\(Int($0))%" } ?? "-")
                MetricTile(title: "Time", value: report.totalDuration.map { "\(Int($0))s" } ?? "-")
            }
        }
        .risePanel()
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
                            Text(event.error)
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
