import AgentToolKit
import KernelCore
import os
import ProviderToolManager

/// Web Fetch 插件（KernelCore 版本）
///
/// 由旧版 `Plugins/WebFetchPlugin`（KernelLumi / LumiPlugin 架构）复刻而来，
/// 纯工具型插件：`onBoot` 解析内核 `NetworkProviding`（供 `WebFetchService`
/// 抓取网页），并向 `ToolManagerProviding` 注册 `WebFetchTool`。
@MainActor
public final class WebFetchPlugin: SuperPlugin {
    public let id = "WebFetch"
    public let order = 100

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.web-fetch")

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("WebFetch", bundle: .module)
    }

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "WebFetch",
            description: "Fetch and extract content from web pages.",
            category: .integration,
            stage: .preview,
            policy: .enabledByDefault
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        WebFetchRuntime.configure(kernel: kernel)

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
        WebFetchRuntime.reset()
    }

    // MARK: - Agent Tools

    public static let agentTools: [any SuperAgentTool] = [
        WebFetchTool(),
    ]
}
