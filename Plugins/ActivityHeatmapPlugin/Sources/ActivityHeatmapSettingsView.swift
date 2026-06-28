import Foundation
import LumiCoreKit
import SwiftUI
import LumiUI

struct ActivityHeatmapSettingsView: View {
    @State private var viewModel: ActivityHeatmapViewModel
    @State private var period: ActivityHeatmapPeriod = .year

    init(historyService: (any HistoryQueryService)?) {
        _viewModel = State(initialValue: ActivityHeatmapViewModel(historyService: historyService))
    }

    var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Activity Heatmap", bundle: .module),
            subtitle: LumiPluginLocalization.string("Conversation activity over time", bundle: .module),
            showHeader: false
        ) {
            // Heatmap card
            AppCard {
                if viewModel.heatmapData.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    ActivityHeatmapView(data: viewModel.heatmapData)
                        .padding(16)
                }
            }

            // Period selector
            AppCard {
                AppSettingsSection(title: LumiPluginLocalization.string("Statistics Period", bundle: .module)) {
                    AppSettingsPickerRow(
                        LumiPluginLocalization.string("Period", bundle: .module),
                        selection: $period
                    ) {
                        ForEach(ActivityHeatmapPeriod.allCases) { p in
                            Text(p.localizedTitle).tag(p)
                        }
                    }
                }
            }
        }
        .onChange(of: period) { _, newValue in
            viewModel.period = newValue
        }
        .task {
            viewModel.period = period
            await viewModel.load()
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
}

#Preview {
    ActivityHeatmapSettingsView(historyService: nil)
        .frame(width: 480, height: 600)
}
