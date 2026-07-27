import LumiKernel
import LumiUI
import SwiftUI

/// 状态栏可用工具详情弹窗视图
struct ToolManagerAvailableToolsDetailView: View {
    @LumiTheme private var theme
    let groups: [(pluginID: String, tools: [any LumiAgentTool])]
    let pluginDisplayNames: [String: String]
    let totalToolCount: Int

    var body: some View {
        StatusBarPopoverScaffold(
            title: "Available Tools",
            systemImage: "wrench.and.screwdriver",
            subtitle: "\(totalToolCount) tools · \(groups.count) plugins"
        ) {
            if groups.isEmpty {
                AppEmptyState(
                    icon: "wrench.and.screwdriver",
                    title: "No tools available"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(groups.enumerated()), id: \.element.pluginID) { _, group in
                            ToolManagerAvailableToolsGroupView(
                                title: displayName(for: group.pluginID),
                                toolCount: group.tools.count,
                                tools: group.tools
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(minHeight: 220, maxHeight: 420)
            }
        }
        .appThemedAppearance()
    }

    private func displayName(for pluginID: String) -> String {
        pluginDisplayNames[pluginID] ?? pluginID
    }
}
