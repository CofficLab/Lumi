import SwiftUI
import LumiKernel
import LumiUI

/// Settings page for the Activity Heatmap plugin.
/// Displayed as a tab in the plugin settings sidebar.
public struct ActivityHeatmapSettingsView: View {
    @State private var viewModel: ActivityHeatmapViewModel
    @State private var period: ActivityHeatmapPeriod = .year

    public init(historyService: (any HistoryQueryService)?) {
        _viewModel = State(initialValue: ActivityHeatmapViewModel(historyService: historyService))
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Activity Heatmap", bundle: .module),
            subtitle: LumiPluginLocalization.string("Conversation activity over time", bundle: .module),
            showHeader: false
        ) {
            // Period selector
            periodSelector

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

    // MARK: - Period Selector

    private var periodSelector: some View {
        AppCard {
            AppSettingsSection(title: LumiPluginLocalization.string("Statistics Period", bundle: .module)) {
                AppSettingsRow {
                    HStack {
                        Text(LumiPluginLocalization.string("Period", bundle: .module))
                            .font(.appBody)
                        Spacer()
                        Picker("", selection: $period) {
                            ForEach(ActivityHeatmapPeriod.allCases) { p in
                                Text(p.localizedTitle).tag(p)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(minWidth: 120)
                    }
                }
            }
        }
    }

    // MARK: - Heatmap Card

    private var heatmapCard: some View {
        AppCard {
            if viewModel.hasLoaded && viewModel.heatmapData.isEmpty && !viewModel.isLoading {
                emptyState
            } else if viewModel.heatmapData.isEmpty {
                loadingView
            } else {
                ActivityHeatmapView(data: viewModel.heatmapData)
                    .padding(16)
                    .overlay(alignment: .topTrailing) {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .padding(8)
                        }
                    }
            }
        }
    }

    // MARK: - Token Chart Card

    private var tokenChartCard: some View {
        AppCard {
            if viewModel.hasLoaded && viewModel.tokenData.isEmpty && !viewModel.isLoading {
                tokenEmptyState
            } else if viewModel.tokenData.isEmpty {
                tokenLoadingView
            } else {
                TokenLineChartView(data: viewModel.tokenData)
                    .padding(16)
                    .overlay(alignment: .topTrailing) {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .padding(8)
                        }
                    }
            }
        }
    }

    // MARK: - Loading / Empty States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(LumiPluginLocalization.string("Loading activity data…", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
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

    private var tokenLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(LumiPluginLocalization.string("Loading token data…", bundle: .module))
                .font(.appCaption)
                .foregroundStyle(.secondary)
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
}

#Preview {
    ActivityHeatmapSettingsView(historyService: nil)
        .frame(width: 480, height: 600)
}
