import os
import Foundation
import KernelCore
import KitSuperLog
import OpenInKit
import ProviderProject
import ProviderDocsView
import ProviderToolManager
import ProviderToolbar

/// 在 Antigravity 中打开项目的插件。
@MainActor
public final class OpenInAntigravityPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.open-in-antigravity", category: "OpenInAntigravity")

    public let id = "com.coffic.lumi.plugin.open-in-antigravity"
    public let order = 614
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.open-in-antigravity",
        name: OpenInAntigravityLocalization.string("Open In Antigravity"),
        description: OpenInAntigravityLocalization.string("Allow LLM to open projects in Antigravity."),
        category: .integration,
        stage: .stable,
        policy: .enabledByDefault
    )

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) {
                OpenInAboutView(displayName: OpenInTool.antigravity.displayName, systemImage: OpenInTool.antigravity.systemImage, toolName: OpenInTool.antigravity.toolName)
            })
            docs.addManual(DocsEntry(id: id, name: metadata.name) {
                OpenInManualView(displayName: OpenInTool.antigravity.displayName, toolName: OpenInTool.antigravity.toolName)
            })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let project = kernel.resolveProvider((any ProjectProviding).self)
        let tool = OpenInTool(config: OpenInTool.antigravity, project: project)

        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
            toolbar.addToolbarItems([
                ToolbarItem(
                    id: "\(id).toolbar",
                    title: OpenInAntigravityLocalization.string("Open In Antigravity"),
                    placement: .leading,
                    category: .global,
                    order: order
                ) {
                    OpenInAntigravityToolbarView(tool: tool, project: project)
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
        toolManager.remove(id: OpenInTool.antigravity.toolName)
    }
}
