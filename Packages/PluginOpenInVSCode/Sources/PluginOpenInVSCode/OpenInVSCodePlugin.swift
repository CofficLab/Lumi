import os
import Foundation
import KernelCore
import LumiLoggingKit
import KitOpenIn
import ProviderProject
import ProviderToast
import ProviderDocsView
import ProviderToolManager
import ProviderToolbar

/// 在 VS Code 中打开项目的插件。
@MainActor
public final class OpenInVSCodePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.open-in-vscode", category: "OpenInVSCode")

    public let id = "com.coffic.lumi.plugin.open-in-vscode"
    public let order = 613
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.open-in-vscode",
        name: OpenInVSCodeLocalization.string("Open In VS Code"),
        description: OpenInVSCodeLocalization.string("Allow LLM to open projects in Visual Studio Code."),
        category: .integration,
        stage: .stable,
        policy: .disabledByDefault
    )

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) {
                OpenInAboutView(displayName: OpenInTool.vscode.displayName, systemImage: OpenInTool.vscode.systemImage, toolName: OpenInTool.vscode.toolName)
            })
            docs.addManual(DocsEntry(id: id, name: metadata.name) {
                OpenInManualView(displayName: OpenInTool.vscode.displayName, toolName: OpenInTool.vscode.toolName)
            })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let project = kernel.resolveProvider((any ProjectProviding).self)
        let tool = OpenInTool(config: OpenInTool.vscode, project: project)

        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
            let projectCapability = OpenInProjectCapabilityAdapter(project: project)
            let failureReporter = OpenInFailureToastReporter(
                toast: kernel.resolveProvider((any ToastProviding).self)
            )
            toolbar.addToolbarItems([
                ToolbarItem(
                    id: "\(id).toolbar",
                    title: OpenInVSCodeLocalization.string("Open In VS Code"),
                    placement: .leading,
                    category: .project,
                    order: order
                ) {
                    OpenInVSCodeToolbarView(
                        tool: tool,
                        projectCapability: projectCapability,
                        failureReporter: failureReporter
                    )
                },
            ])
        }

        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }

        toolManager.add(tool, pluginID: id)
    }

    /// 运行时启用：重新注册工具栏按钮与 Agent 工具。
    public func onEnable(kernel: KernelCoreContainer) async throws {
        try onBoot(kernel: kernel)
    }

    /// 运行时禁用：撤回 Agent 工具与工具栏按钮。
    ///
    /// 内核运行时禁用只调用 `onDisable`（不调用 `onShutdown`），也不会代撤
    /// Provider 侧贡献。此前工具一直留在注册表里，禁用后仍可被 Agent 执行
    /// （见 issue #297）。禁用必须立即撤回，启用时再恢复。
    public func onDisable(kernel: KernelCoreContainer) async throws {
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).toolbar"])
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }
        toolManager.remove(id: OpenInTool.vscode.toolName)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).toolbar"])

        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }
        toolManager.remove(id: OpenInTool.vscode.toolName)
    }
}
