import os
import Foundation
import KernelCore
import KitSuperLog
import OpenInKit
import ProviderProject
import ProviderDocsView
import ProviderToolManager
import ProviderToolbar

/// 在 GitOK 中打开项目的插件。
@MainActor
public final class OpenInGitOKPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.open-in-gitok", category: "OpenInGitOK")

    public let id = "com.coffic.lumi.plugin.open-in-gitok"
    public let order = 616
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.open-in-gitok",
        name: OpenInGitOKLocalization.string("Open In GitOK"),
        description: OpenInGitOKLocalization.string("Allow LLM to open projects in GitOK."),
        category: .integration,
        stage: .stable,
        policy: .enabledByDefault
    )

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) {
                OpenInAboutView(displayName: OpenInTool.gitOK.displayName, systemImage: OpenInTool.gitOK.systemImage, toolName: OpenInTool.gitOK.toolName)
            })
            docs.addManual(DocsEntry(id: id, name: metadata.name) {
                OpenInManualView(displayName: OpenInTool.gitOK.displayName, toolName: OpenInTool.gitOK.toolName)
            })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let project = kernel.resolveProvider((any ProjectProviding).self)
        let tool = OpenInTool(config: OpenInTool.gitOK, project: project)

        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
            toolbar.addToolbarItems([
                ToolbarItem(
                    id: "\(id).toolbar",
                    title: OpenInGitOKLocalization.string("Open In GitOK"),
                    placement: .leading,
                    category: .global,
                    order: order
                ) {
                    OpenInGitOKToolbarView(tool: tool, project: project)
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
        toolManager.remove(id: OpenInTool.gitOK.toolName)
    }
}
