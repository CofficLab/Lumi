import AgentToolKit
import EditorService
import EditorTabStripPlugin
import LumiCoreKit
import os
import SwiftUI

/// Unified code editor plugin for the Lumi activity bar.
public enum EditorPanelPlugin: LumiPlugin {
    public static var verbose: Bool { false }
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lumi-editor")
    public static let policy: LumiPluginPolicy = .optIn
    public static let category: LumiPluginCategory = .development
    public static let iconName = "chevron.left.forwardslash.chevron.right"

    public static let info = LumiPluginInfo(
        id: "LumiEditor",
        displayName: LumiPluginLocalization.string("Code Editor", bundle: .module),
        description: String(
            localized: "Code editor with file tree, LSP, and workspace panels.",
            bundle: .module
        ),
        order: 77
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        guard context.resolve(LumiEditorServicing.self) != nil else {
            return []
        }

        return [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                chatSection: .narrow,
                showsRail: true,
                showsPanelChrome: true
            ) {
                EditorPanelHostView()
            }
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            GetCurrentFileTool().asLumiAgentTool(),
            SetCurrentFileTool().asLumiAgentTool(),
        ]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        pluginAboutView(
            features: [
                .init(icon: "chevron.left.forwardslash.chevron.right", title: "Code Editor", description: "Provides Code Editor capabilities in Lumi."),
                .init(icon: "chevron.left.forwardslash.chevron.right", title: "Editor Extension", description: "Extends the built-in code editor"),
                .init(icon: "paintbrush", title: "Language Support", description: "Improves editing for specific file types")
            ],
            steps: [
                "Enable the plugin in plugin settings",
                "Open a supported file in the editor",
                "Use the editor features provided by this plugin"
            ],
            tips: [
                "Keep only the editor extensions you actively use enabled",
                "Some features depend on language tooling being available"
            ]
        )
    }

}
