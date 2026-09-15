import os
import Foundation
import KernelCore
import KitSuperLog
import OpenInKit
import ProviderProject
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
        policy: .enabledByDefault
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
            toolbar.addToolbarItems([
                ToolbarItem(
                    id: "\(id).toolbar",
                    title: OpenInVSCodeLocalization.string("Open In VS Code"),
                    placement: .leading,
                    category: .global,
                    order: order
                ) {
                    OpenInVSCodeToolbarView(tool: tool, project: project)
                },
            ])
        }

        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }

        toolManager.add(tool, pluginID: id)
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
