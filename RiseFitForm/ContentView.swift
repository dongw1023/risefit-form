import AVKit
import PhotosUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var viewModel: FormAnalysisViewModel
    @State private var playback: VideoPlayback?

    init(authToken: String?) {
        _viewModel = StateObject(wrappedValue: FormAnalysisViewModel(authToken: authToken))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        HeaderView {
                            authService.signOut()
                        }
                        exercisePicker
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
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadHistory()
            }
            .sheet(item: $playback) { playback in
                VideoPlaybackView(playback: playback)
            }
        }
    }

    private var exercisePicker: some View {
        HStack(spacing: 10) {
            ForEach(Exercise.allCases) { exercise in
                Button {
                    viewModel.selectedExercise = exercise
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: exercise == .deadlift ? "figure.strengthtraining.traditional" : "figure.strengthtraining.functional")
                        Text(exercise.title)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(viewModel.selectedExercise == exercise ? Color.black : Color.white.opacity(0.78))
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.selectedExercise == exercise ? Color.riseMint : Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(viewModel.selectedExercise == exercise ? 0 : 0.10), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch viewModel.state {
        case .idle:
            GuidancePanel()
        case .selected:
            ReadyPanel {
                Task { await viewModel.uploadSelectedVideo() }
            }
        case .uploading:
            ProgressPanel(title: "Uploading video", message: "Preparing your clip for form analysis.")
        case .processing(let analysis):
            ProgressPanel(title: "Analysing \(analysis.exercise.capitalized)", message: "Tracking joints, phases, and visible form events.")
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

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.06, blue: 0.07),
                Color(red: 0.08, green: 0.10, blue: 0.10),
                Color(red: 0.03, green: 0.03, blue: 0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct HeaderView: View {
    let onSignOut: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RiseFit Form")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Video form checks for barbell lifts")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                HStack(spacing: 10) {
                    Button(action: onSignOut) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.78))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.09))
                            .frame(width: 48, height: 48)
                        Image(systemName: "waveform.path.ecg.rectangle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.riseMint)
                    }
                }
            }

            HStack(spacing: 10) {
                CapabilityPill(icon: "video.fill", title: "Upload")
                CapabilityPill(icon: "figure.run", title: "Analyse")
                CapabilityPill(icon: "play.rectangle.fill", title: "Replay")
            }
        }
    }
}

private struct CapabilityPill: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }
}

private struct UploadPanel: View {
    @ObservedObject var viewModel: FormAnalysisViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training clip")
                        .font(.system(size: 13, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.riseMint)

                    Text(uploadTitle)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Best results come from a side view with your full body and bar visible.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: uploadIcon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.riseMint)
                    .frame(width: 52, height: 52)
                    .background(Color.black.opacity(0.26))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            PhotosPicker(selection: $viewModel.selectedItem, matching: .videos) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Choose Video")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(Color.riseMint)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .onChange(of: viewModel.selectedItem) {
                Task { await viewModel.loadSelectedVideo() }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var uploadTitle: String {
        if case .selected = viewModel.state {
            return "Video ready"
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

private struct GuidancePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Capture Checklist")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            ChecklistRow(icon: "person.crop.rectangle", text: "Keep the full body in frame")
            ChecklistRow(icon: "camera.metering.center.weighted", text: "Use a stable side angle")
            ChecklistRow(icon: "light.max", text: "Avoid dark or backlit clips")
        }
        .panelStyle()
    }
}

private struct HistoryPanel: View {
    @ObservedObject var viewModel: FormAnalysisViewModel
    let onPlay: (FormAnalysis, HistoryVideoKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uploaded Videos")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Your recent form checks")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer()

                Button {
                    Task { await viewModel.loadHistory() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.riseMint)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            if viewModel.isLoadingHistory && viewModel.analyses.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.riseMint)
                    Text("Loading videos")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.66))
                }
            } else if let historyError = viewModel.historyError {
                Text(historyError)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.46, blue: 0.35))
                    .fixedSize(horizontal: false, vertical: true)
            } else if viewModel.analyses.isEmpty {
                Text("No uploaded videos yet.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.60))
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.analyses) { analysis in
                        HistoryRow(analysis: analysis, onPlay: onPlay) { analysis in
                            Task { await viewModel.reanalyze(analysis) }
                        }
                    }
                }
            }
        }
        .panelStyle()
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
                    .frame(width: 34, height: 34)
                    .background(Color.riseMint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(analysis.exercise.capitalized)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        statusBadge
                    }

                    Text(analysis.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()

                if let score = analysis.report?.formScore {
                    Text("\(Int(score))")
                        .font(.system(size: 20, weight: .black))
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
        .padding(12)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var icon: String {
        analysis.exercise == "deadlift" ? "figure.strengthtraining.traditional" : "figure.strengthtraining.functional"
    }

    private var statusBadge: some View {
        Text(analysis.status.rawValue.capitalized)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.13))
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch analysis.status {
        case .completed:
            return Color.riseMint
        case .failed:
            return Color(red: 1.0, green: 0.46, blue: 0.35)
        case .queued, .processing:
            return Color(red: 1.0, green: 0.78, blue: 0.38)
        }
    }
}

private struct VideoActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.86))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct VideoPlaybackView: View {
    @Environment(\.dismiss) private var dismiss
    let playback: VideoPlayback

    var body: some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(playback.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                VideoPlayer(player: AVPlayer(url: playback.url))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .padding(20)
        }
    }
}

private struct ChecklistRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.riseMint)
                .frame(width: 28, height: 28)
                .background(Color.riseMint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
        }
    }
}

private struct ReadyPanel: View {
    let onAnalyze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.riseMint)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to analyse")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("The backend will return a score, events, and annotated replay.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            Button(action: onAnalyze) {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Analyze Form")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(Color.riseMint)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .panelStyle()
    }
}

private struct ProgressPanel: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ProgressView()
                    .tint(Color.riseMint)
                    .controlSize(.large)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.riseMint)
                            .frame(width: proxy.size.width * 0.58)
                    }
            }
            .frame(height: 8)
        }
        .panelStyle()
    }
}

private struct FailurePanel: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.46, blue: 0.35))
            Text("Analysis failed")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
        }
        .panelStyle()
    }
}

private struct AnalysisResultView: View {
    let analysis: FormAnalysis
    let videoURL: URL?
    let onReanalyze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                }
                .foregroundStyle(Color.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
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
                        .font(.system(size: 13, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.riseMint)

                    Text(report.exercise?.capitalized ?? "Lift")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(max((report.formScore ?? 0) / 100, 0), 1)))
                        .stroke(Color.riseMint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(report.formGrade ?? "-")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                }
                .frame(width: 84, height: 84)
            }

            HStack(spacing: 10) {
                MetricTile(title: "Score", value: report.formScore.map { "\(Int($0))" } ?? "-")
                MetricTile(title: "View", value: report.viewHealth.map { "\(Int($0))%" } ?? "-")
                MetricTile(title: "Time", value: report.totalDuration.map { "\(Int($0))s" } ?? "-")
            }
        }
        .panelStyle()
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct EventsPanel: View {
    let events: [DetectedFormEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coach Notes")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            ForEach(events) { event in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.riseMint)
                        .frame(width: 30, height: 30)
                        .background(Color.riseMint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(event.error)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            if let startTime = event.startTime {
                                Text("\(startTime, specifier: "%.1f")s")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                        }

                        if let coachNote = event.coachNote {
                            Text(coachNote)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.62))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.20))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .panelStyle()
    }
}

private struct CleanLiftPanel: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.riseMint)
            VStack(alignment: .leading, spacing: 4) {
                Text("No major form events detected")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text("Replay the analysed video to inspect your bar path and positions.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .panelStyle()
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

extension Color {
    static let riseMint = Color(red: 0.54, green: 0.97, blue: 0.73)
}
