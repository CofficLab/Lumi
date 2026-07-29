import SwiftUI
import LumiUI
import LumiKernel

/// 工具管理器设置视图
///
/// 设计要点:视图持有 `kernel` 引用,在每次打开时(`.onAppear` / `.task`)
/// 实时从内核 `ToolManager` 拉取当前已注册的工具列表,而非在注册 UI 贡献时
/// 静态捕获一份快照。这样可彻底避免启动阶段工具尚未注册导致的「No Tools Registered」
/// 误显示,并且始终反映内核的真实状态(包括插件启用/禁用后的变更)。
public struct ToolManagerSettingsView: View {
    let kernel: LumiKernel

    @State private var groups: [(pluginID: String, tools: [any LumiAgentTool])] = []
    @State private var pluginDisplayNames: [String: String] = [:]

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Tool Manager", bundle: .module),
            subtitle: LumiPluginLocalization.string("Manage and inspect available agent tools", bundle: .module),
            showHeader: false
        ) {
            VStack(alignment: .leading, spacing: 24) {
                if groups.isEmpty {
                    // 仅在用户实际打开设置、内核中确实没有任何工具时才显示空状态
                    AppEmptyState(
                        icon: "wrench.and.screwdriver",
                        title: LumiPluginLocalization.string("No Tools Registered", bundle: .module),
                        description: LumiPluginLocalization.string("No tools are currently registered in the kernel. Enable plugins to make tools available to the LLM.", bundle: .module)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(Array(groups.enumerated()), id: \.element.pluginID) { _, group in
                        pluginSection(pluginID: group.pluginID, tools: group.tools)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { reload() }
        .onAppear { reload() }
    }

    private func pluginSection(pluginID: String, tools: [any LumiAgentTool]) -> some View {
        let displayName = pluginDisplayNames[pluginID] ?? pluginID

        return AppSettingSection(title: displayName, titleAlignment: .leading) {
            VStack(spacing: 0) {
                ForEach(tools, id: \.name) { tool in
                    ToolManagerToolRowView(tool: tool)
                }
            }
        }
    }

    /// 实时从内核读取当前已注册的工具分组与插件显示名。
    @MainActor
    private func reload() {
        groups = kernel.toolManager?.agentToolsGroupedByPlugin() ?? []
        var names: [String: String] = [:]
        for plugin in kernel.pluginManager.allPlugins {
            names[plugin.id] = plugin.name
        }
        pluginDisplayNames = names
    }
}
