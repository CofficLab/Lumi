import LumiUI
import SwiftUI

/// 工具调用统计，按工具聚合。
///
/// 只依赖 `ToolManagerViewModel`；分页拉取与聚合逻辑在 ViewModel 内完成。
struct ToolCallStatsSettingsView: View {
    @ObservedObject var viewModel: ToolManagerViewModel

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }

    var body: some View {
        AppSettingSection(
            title: L("Usage Statistics"),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingRow(
                    title: String(format: L("%lld total calls"), viewModel.totalCallCount),
                    description: L("Tool usage statistics will appear here once tools are called."),
                    icon: "chart.bar.xaxis"
                ) {
                    AppButton(
                        L("Refresh"),
                        systemImage: "arrow.clockwise",
                        style: .secondary,
                        size: .small
                    ) {
                        viewModel.reloadStatsRequested()
                    }
                }

                Divider()
                    .padding(.vertical, 8)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.stats.enumerated()), id: \.element.id) { index, stat in
                            if index > 0 {
                                Divider()
                                    .padding(.vertical, 8)
                            }
                            ToolStatRowView(stat: stat)
                        }
                        if viewModel.stats.isEmpty {
                            AppEmptyState(
                                icon: "chart.bar.xaxis",
                                title: L("No statistics yet"),
                                description: L("Tool usage statistics will appear here once tools are called.")
                            )
                            .frame(maxWidth: .infinity, minHeight: 200)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await viewModel.reloadStats() }
    }
}

private struct ToolStatRowView: View {
    let stat: ToolStatEntry

    var body: some View {
        AppSettingRow(
            title: stat.toolName,
            description: String(format: LumiPluginLocalization.string("%lld errors", bundle: .module), stat.errorCount),
            icon: "wrench.and.screwdriver"
        ) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: LumiPluginLocalization.string("%lld calls", bundle: .module), stat.totalCount))
                    .font(.appBody)
                    .foregroundStyle(.secondary)
                if stat.averageDuration > 0 {
                    Text(String(format: LumiPluginLocalization.string("avg %.2fs", bundle: .module), stat.averageDuration))
                        .font(.appMicro)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
