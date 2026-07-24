import LocalizationKit
import LumiKernel
import LumiUI
import SwiftUI

/// 工具管理器设置视图
///
/// 展示所有已注册的工具，按插件分组显示。
public struct ToolManagerSettingsView: View {
    let groups: [(pluginID: String, tools: [any LumiAgentTool])]
    let pluginDisplayNames: [String: String]

    public var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                if groups.isEmpty {
                    AppEmptyState(
                        icon: "wrench.and.screwdriver",
                        title: LumiLocalization.string("No tools registered", bundle: .module)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(Array(groups.enumerated()), id: \.element.pluginID) { index, group in
                        pluginSection(pluginID: group.pluginID, tools: group.tools)
                        if index < groups.count - 1 {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func pluginSection(pluginID: String, tools: [any LumiAgentTool]) -> some View {
        let displayName = pluginDisplayNames[pluginID] ?? pluginID

        return AppSettingSection(title: displayName, titleAlignment: .leading) {
            VStack(spacing: 0) {
                ForEach(Array(tools.enumerated()), id: \.element.name) { index, tool in
                    AppSettingRow(
                        title: tool.name,
                        description: tool.toolDescription,
                        icon: "wrench.and.screwdriver"
                    ) {
                        EmptyView()
                    }
                    if index < tools.count - 1 {
                        Divider()
                            .padding(.vertical, 8)
                    }
                }
            }
        }
    }
}
