import os
import Foundation
import KernelCore
import KitSuperLog
import OpenInKit
import ProviderProject
import ProviderDocsView
import ProviderToolManager
import ProviderToolbar

/// 在 Finder 中打开文件或文件夹的插件。
@MainActor
public final class OpenInFinderPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.open-in-finder", category: "OpenInFinder")

    public let id = "com.coffic.lumi.plugin.open-in-finder"
    public let order = 610
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.open-in-finder",
        name: OpenInFinderLocalization.string("Open In Finder"),
        description: OpenInFinderLocalization.string("Allow LLM to open files or folders in Finder."),
        category: .integration,
        stage: .stable,
        policy: .disabledByDefault
    )

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) {
                OpenInAboutView(displayName: OpenInTool.finder.displayName, systemImage: OpenInTool.finder.systemImage, toolName: OpenInTool.finder.toolName)
            })
            docs.addManual(DocsEntry(id: id, name: metadata.name) {
                OpenInManualView(displayName: OpenInTool.finder.displayName, toolName: OpenInTool.finder.toolName)
            })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let project = kernel.resolveProvider((any ProjectProviding).self)
        let tool = OpenInTool(config: OpenInTool.finder, project: project)

        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
            toolbar.addToolbarItems([
                ToolbarItem(
                    id: "\(id).toolbar",
                    title: OpenInFinderLocalization.string("Open In Finder"),
                    placement: .leading,
                    category: .global,
                    order: order
                ) {
                    OpenInFinderToolbarView(tool: tool, project: project)
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
        toolManager.remove(id: OpenInTool.finder.toolName)
    }
}
