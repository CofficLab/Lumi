import AgentToolKit
import EditorService
import LumiCoreKit
import LumiUI
import SuperLogKit
import Foundation
import LumiPreviewKit
import SwiftUI
import os

/// Runtime configuration for inline preview.
public actor EditorPreviewPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview"
    )

    public nonisolated static let emoji = "IP"
    public nonisolated static let verbose: Bool = false
    public static let id: String = "EditorPreview"
    public static let displayName: String = LumiPluginLocalization.string("Inline Preview", bundle: .module)
    public static let description: String = LumiPluginLocalization.string("Embedded preview powered by LumiPreviewKit", bundle: .module)
    public static let iconName: String = "rectangle.inset.filled"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 84 }
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorPreviewPlugin()

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [CleanStringCatalogTool()]
    }

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        EditorPreviewRuntimeBridge.editorServiceProvider = { pluginContext in
            context.editorServiceProvider(pluginContext) as? EditorService
        }
        EditorPreviewRuntimeBridge.addToChatHandler = { text, pluginContext in
            context.addToChat(text, pluginContext)
        }
    }
}
