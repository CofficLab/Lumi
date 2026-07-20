import EditorService
import LumiKernel
import LumiUI
import SwiftUI
import os

/// Editor Preview Bottom Panel Plugin
@MainActor
public final class EditorPreviewBottomPanelPlugin: LumiPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-preview-bottom-panel")

    public let id = "com.coffic.lumi.plugin.editor-bottom-preview"
    public let name = "Editor Preview"
    public let order = 84
public static let policy: LumiPluginPolicy = .disabled

    public init() {}

    public func register(kernel: LumiKernel) throws {
        kernel.panel?.registerPanelBottomTabItem(
            PanelBottomTabItem(
                id: "editor-bottom-preview",
                title: LumiPluginLocalization.string("Preview", bundle: .module),
                systemImage: "eye"
            ) {
                EditorPreviewDetailView(kernel: kernel)
            }
        )
    }

    public func boot(kernel: LumiKernel) async throws {
        EditorPreviewRuntimeBridge.kernel = kernel
    }
}