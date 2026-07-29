import Combine
import LumiUI
import SwiftUI

/// Settings page for Memory monitoring plugin.
/// Displayed as a tab in the plugin settings sidebar.
public struct MemorySettingsView: View {
    @LumiTheme private var theme

    @StateObject private var viewModel = MemorySettingsViewModel()
    @State private var systemMemoryTimeRange: MemoryTimeRange = .hour1
    @State private var lumiMemoryTimeRange: LumiMemoryTimeRange = .minute15

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Memory Monitor", bundle: .module),
            subtitle: LumiPluginLocalization.string("Track Lumi's memory usage over time", bundle: .module),
            showHeader: false
        ) {
            // System Memory Section
            systemMemorySection

            // Divider
            Divider()
                .padding(.vertical, 8)

            // Lumi Memory Section
            lumiMemorySection
        }
        .task {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    // MARK: - System Memory Section

    @ViewBuilder
    private var systemMemorySection: some View {
        // Live memory stats
        liveMemoryCard

        // Time range selector
        timeRangeSelector

        // Memory usage chart
        memoryChartCard

        // Memory statistics
        statisticsCard
    }

    // MARK: - Lumi Memory Section

    @ViewBuilder
    private var lumiMemorySection: some View {
        // Section header
        HStack {
            Image(systemName: "app.fill")
                .foregroundColor(theme.primary)
            Text(LumiPluginLocalization.string("Lumi Memory Usage", bundle: .module))
                .font(.appBody)
                .bold()
            Spacer()
        }
        .padding(.bottom, 4)

        // Current Lumi memory
        lumiMemoryCard

        // Lumi memory chart
        lumiMemoryChartCard

        // Lumi memory statistics
        lumiMemoryStatisticsCard
    }

    // MARK: - Live Memory Card

    private var liveMemoryCard: some View {
        AppCard {
            VStack(spacing: 12) {
                HStack {
                    Text(LumiPluginLocalization.string("System Memory", bundle: .module))
                        .font(.appBody)
                        .bold()
                    Spacer()
                    Text("\(viewModel.currentUsagePercentage, specifier: "%.1f")%")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(usageColor(for: viewModel.currentUsagePercentage))
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.textTertiary.opacity(0.15))

                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        usageColor(for: viewModel.currentUsagePercentage).opacity(0.8),
                                        usageColor(for: viewModel.currentUsagePercentage)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(viewModel.currentUsagePercentage / 100.0))
                    }
                }
                .frame(height: 12)

                HStack {
                    Text(viewModel.usedMemory)
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text(viewModel.totalMemory)
                        .font(.appCaption)
                        .foregroundColor(theme.textTertiary)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Time Range Selector

    private var timeRangeSelector: some View {
        AppCard {
            AppSettingsSection(title: LumiPluginLocalization.string("Time Range", bundle: .module)) {
                AppSettingsRow {
                    HStack {
                        Text(LumiPluginLocalization.string("Period", bundle: .module))
                            .font(.appBody)
                        Spacer()
                        Picker("", selection: $systemMemoryTimeRange) {
                            ForEach(MemoryTimeRange.allCases) { range in
                                Text(range.displayName).tag(range)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                }
            }
        }
    }

    // MARK: - Memory Chart Card

    private var memoryChartCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(LumiPluginLocalization.string("Memory Usage History", bundle: .module))
                        .font(.appBody)
                        .bold()
                    Spacer()
                    if viewModel.isRecording {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(theme.success)
                                .frame(width: 6, height: 6)
                            Text(LumiPluginLocalization.string("Recording", bundle: .module))
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }

                MemoryHistoryGraphView(
                    dataPoints: viewModel.getSystemMemoryData(for: systemMemoryTimeRange),
                    timeRange: systemMemoryTimeRange
                )
                .frame(height: 150)
            }
            .padding(16)
        }
    }

    // MARK: - Statistics Card

    private var statisticsCard: some View {
        AppCard {
            AppSettingsSection(title: LumiPluginLocalization.string("Statistics", bundle: .module)) {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatisticItem(
                        title: LumiPluginLocalization.string("Average", bundle: .module),
                        value: String(format: "%.1f%%", viewModel.systemStatistics.average),
                        icon: "chart.bar.fill"
                    )

                    StatisticItem(
                        title: LumiPluginLocalization.string("Peak", bundle: .module),
                        value: String(format: "%.1f%%", viewModel.systemStatistics.peak),
                        icon: "arrow.up.circle.fill"
                    )

                    StatisticItem(
                        title: LumiPluginLocalization.string("Minimum", bundle: .module),
                        value: String(format: "%.1f%%", viewModel.systemStatistics.minimum),
                        icon: "arrow.down.circle.fill"
                    )

                    StatisticItem(
                        title: LumiPluginLocalization.string("Data Points", bundle: .module),
                        value: "\(viewModel.systemDataPointCount)",
                        icon: "circle.grid.3x3.fill"
                    )
                }
            }
        }
    }

    // MARK: - Lumi Memory Card

    private var lumiMemoryCard: some View {
        AppCard {
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "app.fill")
                            .foregroundColor(Color(hex: "7c5cff"))
                        Text(LumiPluginLocalization.string("Lumi Memory", bundle: .module))
                            .font(.appBody)
                            .bold()
                    }
                    Spacer()
                    Text(viewModel.lumiMemoryFormatted)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "7c5cff"))
                }

                // Lumi memory chart
                LumiMemoryChartView(
                    dataPoints: viewModel.getLumiMemoryData(for: lumiMemoryTimeRange)
                )
                .frame(height: 80)

                // Time range picker
                HStack {
                    Spacer()
                    Picker("", selection: $lumiMemoryTimeRange) {
                        ForEach(LumiMemoryTimeRange.allCases) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    Spacer()
                }
            }
            .padding(16)
        }
    }

    // MARK: - Lumi Memory Chart Card

    private var lumiMemoryChartCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(LumiPluginLocalization.string("Lumi Memory History", bundle: .module))
                    .font(.appBody)
                    .bold()

                LumiMemoryChartView(
                    dataPoints: viewModel.getLumiMemoryData(for: lumiMemoryTimeRange)
                )
                .frame(height: 120)
            }
            .padding(16)
        }
    }

    // MARK: - Lumi Memory Statistics Card

    private var lumiMemoryStatisticsCard: some View {
        AppCard {
            AppSettingsSection(title: LumiPluginLocalization.string("Statistics", bundle: .module)) {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatisticItem(
                        title: LumiPluginLocalization.string("Average", bundle: .module),
                        value: viewModel.lumiStatistics.averageFormatted,
                        icon: "chart.bar.fill"
                    )

                    StatisticItem(
                        title: LumiPluginLocalization.string("Peak", bundle: .module),
                        value: viewModel.lumiStatistics.peakFormatted,
                        icon: "arrow.up.circle.fill"
                    )

                    StatisticItem(
                        title: LumiPluginLocalization.string("Minimum", bundle: .module),
                        value: viewModel.lumiStatistics.minimumFormatted,
                        icon: "arrow.down.circle.fill"
                    )

                    StatisticItem(
                        title: LumiPluginLocalization.string("Data Points", bundle: .module),
                        value: "\(viewModel.lumiDataPointCount)",
                        icon: "circle.grid.3x3.fill"
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func usageColor(for percentage: Double) -> Color {
        if percentage < 50 {
            return theme.success
        } else if percentage < 75 {
            return theme.warning
        } else {
            return theme.error
        }
    }
}

// MARK: - Statistic Item

private struct StatisticItem: View {
    @LumiTheme private var theme

    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.primary)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))

            Text(title)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(theme.textTertiary.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Memory Settings ViewModel

@MainActor
private class MemorySettingsViewModel: ObservableObject {
    // System memory
    @Published var currentUsagePercentage: Double = 0.0
    @Published var usedMemory: String = "0 GB"
    @Published var totalMemory: String = "0 GB"
    @Published var isRecording: Bool = false
    @Published var systemStatistics: SystemMemoryStatistics = .zero

    // Lumi memory
    @Published var lumiMemoryFormatted: String = "0 MB"
    @Published var lumiStatistics: LumiMemoryStatistics = .zero

    private var cancellables = Set<AnyCancellable>()
    private let memoryHistoryService = MemoryHistoryService.shared
    private let lumiMemoryService = LumiMemoryService.shared

    // MARK: - System Memory

    struct SystemMemoryStatistics {
        var average: Double = 0
        var peak: Double = 0
        var minimum: Double = 100

        static let zero = SystemMemoryStatistics()
    }

    var systemDataPointCount: Int {
        memoryHistoryService.recentHistory.count + memoryHistoryService.longTermHistory.count
    }

    func getSystemMemoryData(for range: MemoryTimeRange) -> [MemoryDataPoint] {
        memoryHistoryService.getData(for: range)
    }

    // MARK: - Lumi Memory

    struct LumiMemoryStatistics {
        var averageMB: Double = 0
        var peakMB: Double = 0
        var minimumMB: Double = 0

        var averageFormatted: String { formatMB(averageMB) }
        var peakFormatted: String { formatMB(peakMB) }
        var minimumFormatted: String { formatMB(minimumMB) }

        static let zero = LumiMemoryStatistics()

        private func formatMB(_ mb: Double) -> String {
            if mb >= 1024 {
                return String(format: "%.1f GB", mb / 1024)
            }
            return String(format: "%.0f MB", mb)
        }
    }

    var lumiDataPointCount: Int {
        lumiMemoryService.history.count
    }

    func getLumiMemoryData(for range: LumiMemoryTimeRange) -> [LumiMemoryDataPoint] {
        lumiMemoryService.getData(for: range)
    }

    // MARK: - Monitoring

    func startMonitoring() {
        isRecording = true

        // System memory monitoring
        memoryHistoryService.startRecording()

        MemoryService.shared.$memoryUsagePercentage
            .combineLatest(MemoryService.shared.$usedMemory, MemoryService.shared.$totalMemory)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pct, used, total in
                guard let self else { return }
                self.currentUsagePercentage = pct
                self.usedMemory = ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory)
                self.totalMemory = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .memory)
                self.updateSystemStatistics()
            }
            .store(in: &cancellables)

        // Lumi memory monitoring
        lumiMemoryService.startMonitoring()

        lumiMemoryService.$currentMemoryBytes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.lumiMemoryFormatted = self.lumiMemoryService.currentMemoryFormatted
                self.updateLumiStatistics()
            }
            .store(in: &cancellables)
    }

    func stopMonitoring() {
        isRecording = false
        memoryHistoryService.stopRecording()
        lumiMemoryService.stopMonitoring()
        cancellables.removeAll()
    }

    private func updateSystemStatistics() {
        let recentData = memoryHistoryService.recentHistory
        guard !recentData.isEmpty else {
            systemStatistics = .zero
            return
        }

        let percentages = recentData.map { $0.usagePercentage }
        systemStatistics.average = percentages.reduce(0, +) / Double(percentages.count)
        systemStatistics.peak = percentages.max() ?? 0
        systemStatistics.minimum = percentages.min() ?? 0
    }

    private func updateLumiStatistics() {
        let history = lumiMemoryService.history
        guard !history.isEmpty else {
            lumiStatistics = .zero
            return
        }

        let mbValues = history.map { $0.memoryMB }
        lumiStatistics.averageMB = mbValues.reduce(0, +) / Double(mbValues.count)
        lumiStatistics.peakMB = mbValues.max() ?? 0
        lumiStatistics.minimumMB = mbValues.min() ?? 0
    }
}

#Preview {
    MemorySettingsView()
        .frame(width: 480, height: 900)
}
