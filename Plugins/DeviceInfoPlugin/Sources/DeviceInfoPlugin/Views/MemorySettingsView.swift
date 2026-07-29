import Combine
import LumiUI
import SwiftUI

/// Settings page for Memory monitoring plugin.
/// Displayed as a tab in the plugin settings sidebar.
public struct MemorySettingsView: View {
    @LumiTheme private var theme

    @StateObject private var viewModel = MemorySettingsViewModel()
    @State private var selectedTimeRange: MemoryTimeRange = .hour1

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Memory Monitor", bundle: .module),
            subtitle: LumiPluginLocalization.string("Track Lumi's memory usage over time", bundle: .module),
            showHeader: false
        ) {
            // Live memory stats
            liveMemoryCard

            // Time range selector
            timeRangeSelector

            // Memory usage chart
            memoryChartCard

            // Memory statistics
            statisticsCard
        }
        .task {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    // MARK: - Live Memory Card

    private var liveMemoryCard: some View {
        AppCard {
            VStack(spacing: 12) {
                HStack {
                    Text(LumiPluginLocalization.string("Current Usage", bundle: .module))
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
                        Picker("", selection: $selectedTimeRange) {
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
                    dataPoints: viewModel.getData(for: selectedTimeRange),
                    timeRange: selectedTimeRange
                )
                .frame(height: 200)
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
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatisticItem(
                        title: LumiPluginLocalization.string("Average", bundle: .module),
                        value: String(format: "%.1f%%", viewModel.statistics.average),
                        icon: "chart.bar.fill"
                    )

                    StatisticItem(
                        title: LumiPluginLocalization.string("Peak", bundle: .module),
                        value: String(format: "%.1f%%", viewModel.statistics.peak),
                        icon: "arrow.up.circle.fill"
                    )

                    StatisticItem(
                        title: LumiPluginLocalization.string("Minimum", bundle: .module),
                        value: String(format: "%.1f%%", viewModel.statistics.minimum),
                        icon: "arrow.down.circle.fill"
                    )

                    StatisticItem(
                        title: LumiPluginLocalization.string("Data Points", bundle: .module),
                        value: "\(viewModel.dataPointCount)",
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
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(theme.primary)

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))

            Text(title)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(theme.textTertiary.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Memory Settings ViewModel

@MainActor
private class MemorySettingsViewModel: ObservableObject {
    @Published var currentUsagePercentage: Double = 0.0
    @Published var usedMemory: String = "0 GB"
    @Published var totalMemory: String = "0 GB"
    @Published var isRecording: Bool = false
    @Published var statistics: MemoryStatistics = .zero

    private var cancellables = Set<AnyCancellable>()
    private let memoryHistoryService = MemoryHistoryService.shared

    struct MemoryStatistics {
        var average: Double = 0
        var peak: Double = 0
        var minimum: Double = 100

        static let zero = MemoryStatistics()
    }

    var dataPointCount: Int {
        memoryHistoryService.recentHistory.count + memoryHistoryService.longTermHistory.count
    }

    func startMonitoring() {
        isRecording = true
        memoryHistoryService.startRecording()

        MemoryService.shared.$memoryUsagePercentage
            .combineLatest(MemoryService.shared.$usedMemory, MemoryService.shared.$totalMemory)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pct, used, total in
                guard let self else { return }
                self.currentUsagePercentage = pct
                self.usedMemory = ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory)
                self.totalMemory = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .memory)
                self.updateStatistics()
            }
            .store(in: &cancellables)
    }

    func stopMonitoring() {
        isRecording = false
        memoryHistoryService.stopRecording()
        cancellables.removeAll()
    }

    func getData(for range: MemoryTimeRange) -> [MemoryDataPoint] {
        return memoryHistoryService.getData(for: range)
    }

    private func updateStatistics() {
        let recentData = memoryHistoryService.recentHistory
        guard !recentData.isEmpty else {
            statistics = .zero
            return
        }

        let percentages = recentData.map { $0.usagePercentage }
        statistics.average = percentages.reduce(0, +) / Double(percentages.count)
        statistics.peak = percentages.max() ?? 0
        statistics.minimum = percentages.min() ?? 0
    }
}

#Preview {
    MemorySettingsView()
        .frame(width: 480, height: 700)
}
