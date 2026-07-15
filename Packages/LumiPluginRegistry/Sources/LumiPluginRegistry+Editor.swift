// MARK: - Editor Plugins Imports
import AutoTaskPlugin
import BrowserPlugin
import CADDesignerPlugin
import CaffeinatePlugin
import CodeReviewPlugin
import Foundation
import LumiCoreKit
import AgentDelayMessagePlugin
import DisplayControlPlugin
import EditorCallHierarchyPlugin
import EditorFileTreePlugin
import EditorFileTreeV2Plugin
import EditorBreadcrumbNavPlugin
import EditorOutlinePlugin
import EditorPanelPlugin
import EditorPreviewPlugin
import EditorProblemsPlugin
import EditorReferencesPlugin
import EditorSearchPlugin
import EditorService
import EditorStickySymbolBarPlugin
import EditorSwiftPlugin
import EditorSymbolsPlugin
import EditorTabStripPlugin
import EditorTerminalPlugin
import GitHubPlugin
import GitPlugin
import IdleTimePlugin
import ProjectIssueScannerPlugin
import ProjectOverviewPlugin
import ProjectsPlugin
import ShowImagePlugin
import WebFetchPlugin
import WebSearchPlugin
import AgentTurnNotificationPlugin
import AskUserPlugin

// MARK: - Editor Plugins Extension

extension LumiPluginRegistry {
    /// Editor 插件数组，包含所有编辑器相关的插件。
    ///
    /// 包含：EditorPanelPlugin、Swift 集成、面包屑导航、符号栏、各种 Panel 面板、工具类插件
    public static let editorPlugins: [any LumiPlugin.Type] = [
        // MARK: - Core Editor

        EditorPanelPlugin.self,
        EditorSwiftPlugin.self,
        // EditorSwiftEditorPlugin 是真正注册 Swift 语法 grammar / LSP 的类型（遵循
        // LumiEditorExtensionRegistering）；EditorSwiftPlugin 仅负责 scheme 工具栏等集成。
        // 两者 id 不同（EditorSwift / EditorSwiftIntegration），不会重复登记。
        EditorSwiftEditorPlugin.self,

        // MARK: - Editor Panels

        EditorBreadcrumbHeaderPlugin.self,
        StripHeaderPlugin.self,
        EditorStickySymbolBarHeaderPlugin.self,
        EditorProblemsPanelPlugin.self,
        EditorReferencesPanelPlugin.self,
        EditorSearchPanelPlugin.self,
        EditorSymbolsPanelPlugin.self,
        EditorCallHierarchyPanelPlugin.self,
        EditorPreviewBottomPanelPlugin.self,
        EditorTerminalPanelPlugin.self,
        EditorFileTreePanelPlugin.self,
        EditorFileTreeV2Plugin.self,
        EditorOutlinePanelPlugin.self,

        // MARK: - Editor Tools

        AutoTaskPlugin.self,
        GitHubPlugin.self,
        GitPlugin.self,
        IdleTimePlugin.self,
        ProjectIssueScannerPlugin.self,
        AgentTurnNotificationPlugin.self,
        ProjectsPlugin.self,
        WebSearchPlugin.self,
        WebFetchPlugin.self,
        AskUserPlugin.self,
        CaffeinatePlugin.self,
        BrowserPlugin.self,
        ProjectOverviewPlugin.self,
        ShowImagePlugin.self,
        CodeReviewPlugin.self,
        DelayMessagePlugin.self,
        DisplayControlPlugin.self,
        CADDesignerPlugin.self,
    ]
}
