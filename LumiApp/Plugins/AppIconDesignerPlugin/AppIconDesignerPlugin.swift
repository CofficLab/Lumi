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
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "App Icon Designer",
                subtitle: "用图层、预设和导出工具生成应用图标资源。",
                icon: Self.iconName,
                accent: .pink,
                metrics: [
                    PluginPosterSupport.metric("1024", "画布"),
                    PluginPosterSupport.metric("SVG", "导出"),
                ],
                rows: ["背景与形状图层", "预设应用", "AppIcon 导出"],
                chips: ["设计", "图标", "Agent 工具"]
            ),
            PluginPosterSupport.poster(
                title: "图标文档工作流",
                subtitle: "保存、加载、检查和注册图标产物，适合反复迭代。",
                icon: "square.stack.3d.up",
                accent: .orange,
                rows: ["Lint Icon Document", "Save / Load", "Export App Icon"],
                chips: ["文档", "校验", "导出"]
            ),
        ]
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
