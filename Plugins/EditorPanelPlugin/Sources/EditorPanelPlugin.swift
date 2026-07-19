import EditorService
import EditorTabStripPlugin
import LumiKernel
import LumiUI
import os
import SwiftUI

/// Unified code editor plugin for the Lumi activity bar.
@MainActor
public final class EditorPanelPlugin: LumiPlugin {
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lumi-editor")

    public let id = "LumiEditor"
    public let name = "Code Editor"
    public let order = 77

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.registerViewContainer(
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "chevron.left.forwardslash.chevron.right",
                showsRail: true,
                showsPanelChrome: true
            ) {
                EditorPanelHostView(kernel: kernel)
            }
        )

        // 注册 AgentTools
        kernel.registerAgentTool(GetCurrentFileTool())
        kernel.registerAgentTool(SetCurrentFileTool())
    }

    public func boot(kernel: LumiKernel) async throws {}
}