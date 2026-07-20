import LumiKernel
import LumiUI
import SwiftUI
import os

/// Editor Terminal Plugin
@MainActor
public final class EditorTerminalPlugin: LumiPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-terminal-panel")

    public let id = "com.coffic.lumi.plugin.editor-bottom-terminal"
    public let name = "Editor Terminal"
    public let order = 100

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.panel?.registerPanelBottomTabItem(
            PanelBottomTabItem(
                id: "editor-bottom-terminal",
                title: LumiPluginLocalization.string("Terminal", bundle: .module),
                systemImage: "terminal"
            ) {
                EditorBottomTerminalPanelView()
            }
        )
    }

    public func boot(kernel: LumiKernel) async throws {
        // 设置 RuntimeBridge
        EditorBottomTerminalBridge.kernel = kernel
    }
}