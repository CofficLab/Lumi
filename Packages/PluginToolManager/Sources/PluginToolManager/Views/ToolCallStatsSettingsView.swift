import LumiUI
import SwiftUI

/// 工具调用统计，按工具聚合。
///
/// 只依赖 `ToolManagerViewModel`；分页拉取与聚合逻辑在 ViewModel 内完成。
struct ToolCallStatsSettingsView: View {
    @LumiTheme private var theme
    @ObservedObject var viewModel: ToolManagerViewModel

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        AppCard {
            AppSettingsSection(
                title: L("Usage Statistics")
            ) {
                AppSettingsRow {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.appCallout)
                            .foregroundColor(theme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: L("%lld total calls"), viewModel.totalCallCount))
                                .font(.appBody)
                                .foregroundColor(theme.textPrimary)
                            Text(L("Tool usage statistics will appear here once tools are called."))
                                .font(.appCaption)
                                .foregroundColor(theme.textSecondary)
                        }

                        Spacer()

                        AppButton(
                            L("Refresh"),
                            systemImage: "arrow.clockwise",
                            style: .secondary,
                            size: .small
                        ) {
                            viewModel.reloadStatsRequested()
                        }
                    }
                }

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.stats, id: \.id) { stat in
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await viewModel.reloadStats() }
    }
}

private struct ToolStatRowView: View {
    let stat: ToolStatEntry

    @LumiTheme private var theme

    var body: some View {
        AppSettingsRow {
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.appCallout)
                    .foregroundColor(theme.primary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.toolName)
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                    Text(String(format: pluginLocalization.string("%lld errors"), stat.errorCount))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: pluginLocalization.string("%lld calls"), stat.totalCount))
                        .font(.appBody)
                        .foregroundStyle(.secondary)
                    if stat.averageDuration > 0 {
                        Text(String(format: pluginLocalization.string("avg %.2fs"), stat.averageDuration))
                            .font(.appMicro)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
