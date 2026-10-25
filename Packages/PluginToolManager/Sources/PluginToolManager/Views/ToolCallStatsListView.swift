import LumiUI
import SwiftUI

/// 工具调用统计列表（主从布局的左栏）：按工具聚合的调用统计。
///
/// 只依赖 `ToolManagerViewModel`；分页拉取与聚合逻辑在 ViewModel 内完成。
struct ToolCallStatsListView: View {
    @ObservedObject var viewModel: ToolManagerViewModel
    @LumiTheme private var theme

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.stats) { stat in
                    statRow(stat)
                }

                if viewModel.stats.isEmpty {
                    AppEmptyState(
                        icon: "chart.bar.xaxis",
                        title: L("No statistics yet"),
                        description: L("Tool usage statistics will appear here once tools are called.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }
            .padding(8)
        }
        .frame(maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
    }

    // MARK: - Rows

    private func statRow(_ stat: ToolStatEntry) -> some View {
        let isSelected = viewModel.selectedStatToolName == stat.toolName
        return AppListRow(isSelected: isSelected, action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectStat(named: stat.toolName)
            }
        }) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.appBody)
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(stat.toolName)
                        .font(.appCaptionEmphasized)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(String(format: L("%lld errors"), stat.errorCount))
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(String(format: L("%lld calls"), stat.totalCount))
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}
