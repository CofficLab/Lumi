import os
import Foundation
import KernelCore
import KitSuperLog
import OpenInKit
import ProviderProject
import ProviderDocsView
import ProviderToolManager
import ProviderToolbar

/// 在 GitHub Desktop 中打开项目的插件。
@MainActor
public final class OpenInGitHubDesktopPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.open-in-github-desktop", category: "OpenInGitHubDesktop")

    public let id = "com.coffic.lumi.plugin.open-in-github-desktop"
    public let order = 615
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.open-in-github-desktop",
        name: OpenInGitHubDesktopLocalization.string("Open In GitHub Desktop"),
        description: OpenInGitHubDesktopLocalization.string("Allow LLM to open projects in GitHub Desktop."),
        category: .integration,
        stage: .stable,
        policy: .disabledByDefault
    )

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) {
                OpenInAboutView(displayName: OpenInTool.gitHubDesktop.displayName, systemImage: OpenInTool.gitHubDesktop.systemImage, toolName: OpenInTool.gitHubDesktop.toolName)
            })
            docs.addManual(DocsEntry(id: id, name: metadata.name) {
                OpenInManualView(displayName: OpenInTool.gitHubDesktop.displayName, toolName: OpenInTool.gitHubDesktop.toolName)
            })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let project = kernel.resolveProvider((any ProjectProviding).self)
        let tool = OpenInTool(config: OpenInTool.gitHubDesktop, project: project)

        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
            toolbar.addToolbarItems([
                ToolbarItem(
                    id: "\(id).toolbar",
                    title: OpenInGitHubDesktopLocalization.string("Open In GitHub Desktop"),
                    placement: .leading,
                    category: .global,
                    order: order
                ) {
                    OpenInGitHubDesktopToolbarView(tool: tool, project: project)
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
        toolManager.remove(id: OpenInTool.gitHubDesktop.toolName)
    }
}
