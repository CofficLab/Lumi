import KitAgentTool
import KernelCore
import os
import ProviderToolManager
import KitSuperLog

/// Docx Read 插件（KernelCore 版本）
///
/// 由旧版 `Plugins/DocxReadPlugin`（KernelLumi / LumiPlugin 架构）复刻而来，
/// 纯工具型插件：`onBoot` 向 `ToolManagerProviding` 注册 `DocxReadTool`。
@MainActor
public final class DocxReadPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.docx-read", category: "DocxRead")
    public let id = "com.coffic.lumi.plugin.docx-read"
    public let order = 90
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.docx-read",
        name: "Docx Read",
        description: "",
        category: .integration,
        stage: .stable,
        policy: .required
    )

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.docx-read")

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("Docx Read", bundle: .module)
    }


    public func onBoot(kernel: KernelCoreContainer) throws {
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
    }

    // MARK: - Agent Tools

    public static let agentTools: [any SuperAgentTool] = [
        DocxReadTool(),
    ]
}
