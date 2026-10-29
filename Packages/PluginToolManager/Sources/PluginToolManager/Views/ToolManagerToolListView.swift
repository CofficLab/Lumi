import KitAgentTool
import LumiUI
import SwiftUI

/// 工具列表（主从布局的左栏）：按插件分组列出内核里已注册的工具。
///
/// 工具数量可达上百个，因此按插件分组并用 `AppSectionLabel` 标出组名；
/// 组内每行只显示工具名，点击即选中，右侧详情随之切换。
struct ToolManagerToolListView: View {
    @ObservedObject var viewModel: ToolManagerViewModel
    @LumiTheme private var theme

    private func L(_ key: String) -> String {
        pluginLocalization.string(key)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(viewModel.groups, id: \.pluginID) { group in
                    AppSectionLabel(groupTitle(for: group.pluginID))
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                        .padding(.bottom, 2)

                    ForEach(group.tools, id: \.name) { tool in
                        toolRow(tool)
                    }
                }

                if viewModel.groups.isEmpty {
                    AppEmptyState(
                        icon: "wrench.and.screwdriver",
                        title: L("No Tools Registered"),
                        description: L("No tools are currently registered in the kernel.")
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

    /// 分组标题：去掉反向 DNS 前缀，只留可读部分。
    ///
    /// `com.coffic.lumi.plugin.agent-rules` → `agent-rules`。完整 pluginID
    /// 仍然显示在右侧详情里，信息不丢。
    private func groupTitle(for pluginID: String) -> String {
        for prefix in ["com.coffic.lumi.plugin.", "com.coffic.lumi.", "com.coffic."] where pluginID.hasPrefix(prefix) {
            return String(pluginID.dropFirst(prefix.count))
        }
        return pluginID
    }

    private func toolRow(_ tool: any SuperAgentTool) -> some View {
        let isSelected = viewModel.selectedToolName == tool.name
        return AppListRow(isSelected: isSelected, action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.selectTool(named: tool.name)
            }
        }) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.appBody)
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 22, height: 22)
                Text(tool.name)
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
    }
}
