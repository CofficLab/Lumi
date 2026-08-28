import KitAgentTool
import KernelCore
import os
import ProviderToolManager
import KitSuperLog

/// Web Fetch 插件（KernelCore 版本）
///
/// 由旧版 `Plugins/WebFetchPlugin`（KernelLumi / LumiPlugin 架构）复刻而来，
/// 纯工具型插件：`onBoot` 解析内核 `NetworkProviding`（供 `WebFetchService`
/// 抓取网页），并向 `ToolManagerProviding` 注册 `WebFetchTool`。
@MainActor
public final class WebFetchPlugin: SuperPlugin, SuperLog {
    public let id = "WebFetch"
    public let order = 100
    public let metadata = PluginMetadata(
        id: "WebFetch",
        name: "Web Fetch",
        description: "",
        category: .integration,
        stage: .stable,
        policy: .required
    )

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.web-fetch")

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("WebFetch", bundle: .module)
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
