import AppKit
import SwiftUI
import LumiKernel
import LumiUI

/// Settings page for the Activity Heatmap plugin.
/// Displayed as a tab in the plugin settings sidebar.
public struct ActivityHeatmapSettingsView: View {
    @State private var viewModel: ActivityHeatmapViewModel
    @State private var period: ActivityHeatmapPeriod = .year
    @LumiTheme private var theme

    private let cacheDirectory: URL?

    public init(messageService: (any MessageManaging)?, cache: ActivityHeatmapCache? = nil) {
        _viewModel = State(initialValue: ActivityHeatmapViewModel(messageService: messageService, cache: cache))
        self.cacheDirectory = cache?.databaseDirectoryURL
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Activity Heatmap", bundle: .module),
            subtitle: LumiPluginLocalization.string("Conversation activity over time", bundle: .module),
            showHeader: false
        ) {
            header

            statisticsOverview

            // Heatmap card
            heatmapCard

            // Token usage line chart card
            tokenChartCard
        }
        .onChange(of: period) { _, newValue in
            guard viewModel.period != newValue else { return }
            viewModel.period = newValue
            Task { await viewModel.load() }
        }
        .task {
            viewModel.period = period
            await viewModel.load()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Spacer()

            HStack(spacing: 6) {
                Text(LumiPluginLocalization.string("Period", bundle: .module))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)

                Picker("", selection: $period) {
                    ForEach(ActivityHeatmapPeriod.allCases) { p in
                        Text(p.localizedTitle).tag(p)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            if cacheDirectory != nil {
                AppButton("Open Data Directory", systemImage: "folder", size: .small) {
                    openDataDirectory()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Heatmap Card

    private var statisticsOverview: some View {
        let stats = viewModel.statistics
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                statisticCard("Messages", value: format(stats.totalMessages), detail: "Total")
                statisticCard("Active days", value: "\(stats.activeDays)/\(period.rawValue)", detail: percent(stats.activeDays, of: period.rawValue))
                statisticCard("Daily average", value: format(stats.averageMessagesPerDay), detail: "Messages")
                statisticCard("Current streak", value: "\(stats.currentStreak)d", detail: "Days")
            }

            HStack(alignment: .top, spacing: 12) {
                insightCard(title: "Records", rows: [
                    ("Most active day", peakMessageText(stats.peakMessageDay)),
                    ("Best streak", "\(stats.longestStreak) days"),
                    ("Longest idle", "\(stats.longestIdleStreak) days"),
                    ("Avg. active day", format(stats.averageMessagesPerActiveDay) + " messages")
                ])
                insightCard(title: "Token usage", rows: [
                    ("Total tokens", format(stats.totalTokens)),
                    ("Daily average", format(stats.averageTokensPerDay)),
                    ("Peak day", peakTokenText(stats.peakTokenDay)),
                    ("Per message", format(stats.averageTokensPerMessage))
                ])
            }

            weekdayDistribution(stats.weekdayTotals)
        }
        .padding(.horizontal, 16)
    }

    private func statisticCard(_ title: String, value: String, detail: String) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 5) {
                Text(LumiPluginLocalization.string(title, bundle: .module))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(LumiPluginLocalization.string(detail, bundle: .module))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }

    private func insightCard(title: String, rows: [(String, String)]) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 9) {
                Text(LumiPluginLocalization.string(title, bundle: .module))
                    .font(.appBody.weight(.semibold))
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(LumiPluginLocalization.string(row.0, bundle: .module))
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(row.1)
                            .font(.appCaption.weight(.medium))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func weekdayDistribution(_ totals: [Int]) -> some View {
        let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let maxValue = max(totals.max() ?? 0, 1)
        return AppCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(LumiPluginLocalization.string("Activity by weekday", bundle: .module))
                    .font(.appBody.weight(.semibold))
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.primary)
                                .frame(height: max(4, CGFloat(totals[index]) / CGFloat(maxValue) * 54))
                            Text(LumiPluginLocalization.string(labels[index], bundle: .module))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(14)
        }
    }

    private var heatmapCard: some View {
        AppCard {
            if viewModel.hasLoaded && viewModel.heatmapData.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                ActivityHeatmapView(
                    data: viewModel.heatmapData.isEmpty ? loadingHeatmapData : viewModel.heatmapData,
                    isLoading: !viewModel.hasLoaded || viewModel.isLoading
                )
                    .padding(16)
            }
        }
    }

    // MARK: - Token Chart Card

    private var tokenChartCard: some View {
        AppCard {
            if viewModel.hasLoaded && viewModel.tokenData.isEmpty && !viewModel.isLoading {
                tokenEmptyState
            } else {
                TokenLineChartView(
                    data: viewModel.tokenData.isEmpty ? loadingTokenData : viewModel.tokenData,
                    isLoading: !viewModel.hasLoaded || viewModel.isLoading
                )
                    .padding(16)
            }
        }
    }

    // MARK: - Loading / Empty States

    private var loadingHeatmapData: [ActivityDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = period.rawValue
        guard let oldestDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: oldestDay) else {
                return nil
            }
            return ActivityDay(date: date, level: 0, messageCount: 0)
        }
    }

    private var loadingTokenData: [ActivityDayToken] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = period.rawValue
        guard let oldestDay = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: oldestDay) else {
                return nil
            }
            return ActivityDayToken(date: date, totalTokens: 0)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(LumiPluginLocalization.string("No data available yet. Start a conversation to see activity.", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private var tokenEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(LumiPluginLocalization.string("No token data available yet.", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // MARK: - Actions

    private func openDataDirectory() {
        guard let url = cacheDirectory else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }

    private func format(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName))
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func percent(_ value: Int, of total: Int) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((Double(value) / Double(total) * 100).rounded()))%"
    }

    private func peakMessageText(_ day: ActivityDay?) -> String {
        guard let day else { return "—" }
        return "\(day.messageCount) · \(day.date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func peakTokenText(_ day: ActivityDayToken?) -> String {
        guard let day else { return "—" }
        return "\(format(day.totalTokens)) · \(day.date.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

#Preview {
    ActivityHeatmapSettingsView(messageService: nil, cache: nil)
        .frame(width: 480, height: 600)
}
