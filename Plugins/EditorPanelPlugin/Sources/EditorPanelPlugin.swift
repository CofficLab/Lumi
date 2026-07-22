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
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func onReady(kernel: LumiKernel) throws {
        guard Self.policy.shouldRegister else { return }
        kernel.viewContainer?.register(
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "chevron.left.forwardslash.chevron.right"
            ) {
                EditorPanelHostView(kernel: kernel)
            }
        )

        // 注册 AgentTools
        kernel.toolManager?.add(GetCurrentFileTool())
        kernel.toolManager?.add(SetCurrentFileTool())
    }

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - Workspace State

    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility {
        // Editor 容器：显示 rail + content + panel，不显示 chat
        WorkspaceVisibility(
            rail: true,
            chat: false,
            content: true,
            activityBar: true,
            panel: true
        )
    }

    public func onContainerActivated(kernel: LumiKernel, containerID: String) {
        guard containerID == id else { return }
        kernel.workspaceState?.applyVisibility(
            rail: true,
            chat: false,
            content: true,
            activityBar: true,
            panel: true
        )
    }
}