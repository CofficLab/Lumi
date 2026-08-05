import AppKit
import SwiftUI
import LumiKernel
import LumiUI

/// Settings page for the Activity Heatmap plugin.
/// Displayed as a tab in the plugin settings sidebar.
public struct ActivityHeatmapSettingsView: View {
    @State private var viewModel: ActivityHeatmapViewModel
    @State private var period: ActivityHeatmapPeriod

    private let cacheDirectory: URL?
    private let settingsStore: ActivityHeatmapSettingsStore?
    private let idleTimeProvider: (any IdleTimeProviding)?
    private let idleTimeDataDirectory: URL?

    public init(messageService: (any MessageManaging)?, cache: ActivityHeatmapCache? = nil,
                settingsStore: ActivityHeatmapSettingsStore? = nil,
                idleTimeProvider: (any IdleTimeProviding)? = nil,
                idleTimeDataDirectory: URL? = nil) {
        _viewModel = State(initialValue: ActivityHeatmapViewModel(messageService: messageService, cache: cache))
        self.settingsStore = settingsStore
        let savedSettings = settingsStore?.loadSettings()
        let savedPeriod = ActivityHeatmapPeriod(rawValue: savedSettings?.selectedPeriodRawValue ?? 0) ?? .days30
        _period = State(initialValue: savedPeriod)
        self.cacheDirectory = cache?.databaseDirectoryURL
        self.idleTimeProvider = idleTimeProvider
        self.idleTimeDataDirectory = idleTimeDataDirectory
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Activity Heatmap", bundle: .module),
            subtitle: LumiPluginLocalization.string("Conversation activity over time", bundle: .module),
            showHeader: false
        ) {
            header

            // Heatmap card
            heatmapCard

            // Token usage line chart card
            tokenChartCard

            // Idle-time tracking is part of activity settings.
            if idleTimeProvider != nil {
                IdleTimeSettingsCard(provider: idleTimeProvider, dataDirectory: idleTimeDataDirectory)
            }
        }
        .onChange(of: period) { _, newValue in
            settingsStore?.saveSettings(ActivityHeatmapSettingsStore.Settings(selectedPeriodRawValue: newValue.rawValue))
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
                AppButton(LumiPluginLocalization.string("Open Data Directory", bundle: .module), systemImage: "folder", size: .small) {
                    openDataDirectory()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Heatmap Card

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

}

#Preview {
    ActivityHeatmapSettingsView(messageService: nil, cache: nil)
        .frame(width: 480, height: 600)
}
