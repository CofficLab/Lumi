import os
import Foundation
import KernelCore
import KitSuperLog
import OpenInKit
import ProviderProject
import ProviderDocsView
import ProviderToolManager

/// 在 Cursor 中打开项目的插件。
@MainActor
public final class OpenInCursorPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.open-in-cursor", category: "OpenInCursor")

    public let id = "com.coffic.lumi.plugin.open-in-cursor"
    public let order = 612
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.open-in-cursor",
        name: "Open In Cursor",
        description: "Allow LLM to open projects in Cursor.",
        category: .integration,
        stage: .stable,
        policy: .enabledByDefault
    )

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) {
                OpenInAboutView(displayName: OpenInTool.cursor.displayName, systemImage: OpenInTool.cursor.systemImage, toolName: OpenInTool.cursor.toolName)
            })
            docs.addManual(DocsEntry(id: id, name: metadata.name) {
                OpenInManualView(displayName: OpenInTool.cursor.displayName, toolName: OpenInTool.cursor.toolName)
            })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }
        let project = kernel.resolveProvider((any ProjectProviding).self)

        let tool = OpenInTool(config: OpenInTool.cursor, project: project)
        toolManager.add(tool, pluginID: id)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }
        toolManager.remove(id: OpenInTool.cursor.toolName)
    }
}
