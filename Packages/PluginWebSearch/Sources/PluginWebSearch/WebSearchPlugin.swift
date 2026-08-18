import AgentToolKit
import KernelCore
import os
import ProviderToolManager

/// Web Search 插件（KernelCore 版本）
///
/// 由旧版 `Plugins/WebSearchPlugin`（KernelLumi / LumiPlugin 架构）复刻而来，
/// 纯工具型插件：`onBoot` 解析内核 `NetworkProviding`（供工具抓取 DuckDuckGo），
/// 并向 `ToolManagerProviding` 注册 `WebSearchTool`。
@MainActor
public final class WebSearchPlugin: SuperPlugin {
    public let id = "WebSearch"
    public let order = 101

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.web-search")

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("WebSearch", bundle: .module)
    }

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "WebSearch",
            description: "Search the web for information using search engines.",
            category: .integration,
            stage: .preview,
            policy: .required
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        WebSearchRuntime.configure(kernel: kernel)

        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.add(tool, pluginID: id)
            }
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            for tool in Self.agentTools {
                toolManager.remove(id: tool.name)
            }
        }
        WebSearchRuntime.reset()
    }

    // MARK: - Agent Tools

    public static let agentTools: [any SuperAgentTool] = [
        WebSearchTool(),
    ]
}
