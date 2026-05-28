import Foundation
import AgentToolKit
import PluginAppIconDesigner
import SwiftUI
import os

actor AppIconDesignerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-icon-designer")

    nonisolated static let emoji = "🎨"
    nonisolated static let verbose = true

    static let id = PluginAppIconDesigner.AppIconDesignerPlugin.id
    static let displayName = PluginAppIconDesigner.AppIconDesignerPlugin.displayName
    static let description = PluginAppIconDesigner.AppIconDesignerPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginAppIconDesigner.AppIconDesignerPlugin.description(for: language)
    }
    static let iconName = PluginAppIconDesigner.AppIconDesignerPlugin.iconName
    static var category: PluginCategory { .general }
    static var order: Int { PluginAppIconDesigner.AppIconDesignerPlugin.order }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }

    static let shared = AppIconDesignerPlugin()

    nonisolated func onRegister() {
        if Self.verbose {
            Self.logger.info("\(Self.t) registered")
        }
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(PluginAppIconDesigner.AppIconDesignerView())
        }
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            PluginAppIconDesigner.ApplyIconPresetTool(),
            PluginAppIconDesigner.CreateIconDocumentTool(),
            PluginAppIconDesigner.SetIconBackgroundTool(),
            PluginAppIconDesigner.AddIconShapeTool(),
            PluginAppIconDesigner.UpdateIconLayerTool(),
            PluginAppIconDesigner.UpdateIconShapeTool(),
            PluginAppIconDesigner.LintIconDocumentTool(),
            PluginAppIconDesigner.SaveIconDocumentTool(),
            PluginAppIconDesigner.LoadIconDocumentTool(),
            PluginAppIconDesigner.ExportIconSVGTool(),
            PluginAppIconDesigner.RegisterAppIconArtifactTool(),
            PluginAppIconDesigner.ExportAppIconTool(),
        ]
    }
}
