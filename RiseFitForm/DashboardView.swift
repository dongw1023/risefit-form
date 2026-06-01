import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: FormAnalysisViewModel

    var body: some View {
        ZStack {
            RiseAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    statsGrid
                    exerciseBreakdown
                    recentActivity
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 100)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dashboard")
                .riseFont(.header)
                .foregroundStyle(Color.riseText)
            Text("Your lifting progress at a glance")
                .riseFont(.bodyBold)
                .foregroundStyle(Color.riseMint.opacity(0.85))
        }
    }

    private var statsGrid: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatCard(title: "Total Lifts", value: "\(viewModel.analyses.count)", icon: "bolt.fill")
                StatCard(title: "Avg Score", value: avgScore, icon: "chart.line.uptrend.xyaxis")
            }
            HStack(spacing: 16) {
                StatCard(title: "Peak Score", value: peakScore, icon: "crown.fill")
                StatCard(title: "View Health", value: avgViewHealth, icon: "camera.fill")
            }
        }
    }

    private var exerciseBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exercise Distribution")
                .riseFont(.subtitle)
                .foregroundStyle(Color.riseText)

            VStack(spacing: 12) {
                let distribution = calculateDistribution()
                if distribution.isEmpty {
                    Text("Start analysing to see your distribution.")
                        .riseFont(.bodyMedium)
                        .foregroundStyle(Color.riseText.opacity(0.4))
                        .padding(.vertical, 10)
                } else {
                    ForEach(distribution.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                        DistributionRow(title: key.replacingOccurrences(of: "_", with: " ").capitalized, count: value, total: viewModel.analyses.count)
                    }
                }
            }
            .risePanel(padding: 18)
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .riseFont(.subtitle)
                .foregroundStyle(Color.riseText)

            if viewModel.analyses.isEmpty {
                Text("No activity yet.")
                    .riseFont(.bodyMedium)
                    .foregroundStyle(Color.riseText.opacity(0.4))
                    .risePanel()
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.analyses.prefix(3)) { analysis in
                        ActivityRow(analysis: analysis)
                    }
                }
            }
        }
    }

    // --- Helpers ---
    
    private var avgScore: String {
        let scores = viewModel.analyses.compactMap { $0.report?.formScore }
        guard !scores.isEmpty else { return "-" }
        return "\(Int(scores.reduce(0, +) / Double(scores.count)))"
    }

    private var peakScore: String {
        let scores = viewModel.analyses.compactMap { $0.report?.formScore }
        guard let maxScore = scores.max() else { return "-" }
        return "\(Int(maxScore))"
    }
    
    private var avgViewHealth: String {
        let scores = viewModel.analyses.compactMap { $0.report?.viewHealth }
        guard !scores.isEmpty else { return "-" }
        return "\(Int(scores.reduce(0, +) / Double(scores.count)))%"
    }

    private func calculateDistribution() -> [String: Int] {
        var counts: [String: Int] = [:]
        for analysis in viewModel.analyses {
            counts[analysis.exercise, default: 0] += 1
        }
        return counts
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.riseMint)
                .frame(width: 40, height: 40)
                .background(Color.riseMint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .riseFont(.title)
                    .foregroundStyle(Color.riseText)
                Text(title)
                    .riseFont(.caption)
                    .foregroundStyle(Color.riseText.opacity(0.5))
            }
        }
        .risePanel(padding: 18)
    }
}

private struct DistributionRow: View {
    let title: String
    let count: Int
    let total: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .riseFont(.bodyBold)
                    .foregroundStyle(Color.riseText)
                Spacer()
                Text("\(count) lifts")
                    .riseFont(.caption)
                    .foregroundStyle(Color.riseText.opacity(0.6))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.riseText.opacity(0.06))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.riseMint)
                        .frame(width: proxy.size.width * CGFloat(count) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 6)
        }
    }
}

private struct ActivityRow: View {
    let analysis: FormAnalysis

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: exerciseIcon(for: analysis.exercise))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.riseText)
                .frame(width: 32, height: 32)
                .background(Color.riseText.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(analysis.exercise.replacingOccurrences(of: "_", with: " ").capitalized)
                    .riseFont(.bodyBold)
                    .foregroundStyle(Color.riseText)
                Text(analysis.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .riseFont(.caption)
                    .foregroundStyle(Color.riseText.opacity(0.4))
            }

            Spacer()

            if let score = analysis.report?.formScore {
                Text("\(Int(score))")
                    .riseFont(.bodyBold)
                    .foregroundStyle(Color.riseMint)
            }
        }
        .padding(14)
        .background(Color.riseText.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func exerciseIcon(for exercise: String) -> String {
        switch exercise.lowercased() {
        case "deadlift": return "figure.strengthtraining.traditional"
        case "squat": return "figure.strengthtraining.functional"
        case "bench_press": return "figure.arms.open"
        default: return "figure.run"
        }
    }
}
