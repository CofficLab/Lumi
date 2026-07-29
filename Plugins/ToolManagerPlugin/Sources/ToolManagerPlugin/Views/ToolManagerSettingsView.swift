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
    @State private var isLoading = true
    @State private var isReloading = false
    @State private var visibleToolLimit = 100

    private let toolPageSize = 100

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Tool Manager", bundle: .module),
            subtitle: LumiPluginLocalization.string("Manage and inspect available agent tools", bundle: .module),
            showHeader: false,
            scrollsContent: false
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Text(totalToolLabel)
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }

                if isLoading {
                    ProgressView(LumiPluginLocalization.string("Loading...", bundle: .module))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if groups.isEmpty {
                    AppEmptyState(
                        icon: "wrench.and.screwdriver",
                        title: LumiPluginLocalization.string("No Tools Registered", bundle: .module),
                        description: LumiPluginLocalization.string("No tools are currently registered in the kernel. Enable plugins to make tools available to the LLM.", bundle: .module)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ForEach(displayedGroups, id: \.pluginID) { group in
                                pluginSection(pluginID: group.pluginID, tools: group.tools)
                            }

                            if visibleToolLimit < totalToolCount {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .onAppear {
                                        visibleToolLimit += toolPageSize
                                    }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .task {
            await reload()
        }
    }

    private var totalToolCount: Int {
        groups.reduce(0) { $0 + $1.tools.count }
    }

    private var totalToolLabel: String {
        if isLoading {
            return LumiPluginLocalization.string("Loading...", bundle: .module)
        }
        return "\(totalToolCount) tools"
    }

    private var displayedGroups: [(pluginID: String, tools: [any LumiAgentTool])] {
        var remaining = visibleToolLimit
        var result: [(pluginID: String, tools: [any LumiAgentTool])] = []
        result.reserveCapacity(groups.count)

        for group in groups {
            guard remaining > 0 else { break }
            let visibleTools = Array(group.tools.prefix(remaining))
            guard !visibleTools.isEmpty else { continue }
            result.append((pluginID: group.pluginID, tools: visibleTools))
            remaining -= visibleTools.count
        }
        return result
    }

    private func pluginSection(pluginID: String, tools: [any LumiAgentTool]) -> some View {
        let displayName = pluginDisplayNames[pluginID] ?? pluginID

        return AppSettingSection(title: displayName, titleAlignment: .leading) {
            LazyVStack(spacing: 0) {
                ForEach(tools, id: \.name) { tool in
                    ToolManagerToolRowView(tool: tool)
                }
            }
        }
    }

    /// 实时从内核读取当前已注册的工具分组与插件显示名。
    @MainActor
    private func reload() async {
        guard !isReloading else { return }
        isReloading = true
        isLoading = true
        defer {
            isReloading = false
            isLoading = false
        }

        // 让 SwiftUI 先提交 loading 状态，再读取当前内存注册表。
        await Task.yield()
        groups = kernel.toolManager?.agentToolsGroupedByPlugin() ?? []
        var names: [String: String] = [:]
        for plugin in kernel.pluginManager.allPlugins {
            names[plugin.id] = plugin.name
        }
        pluginDisplayNames = names
        visibleToolLimit = toolPageSize
    }
}
