import AgentToolKit
import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

/// Xcode 集成插件：scheme 工具栏、构建上下文状态栏与 Agent 工具。
public enum EditorXcodePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .development
    public static let iconName = "xmark.app"

    /// Code Editor 面板 section id（与 `EditorPanelPlugin.info.id` 一致）。
    private static let editorPanelSectionID = "LumiEditor"

    public static let info = LumiPluginInfo(
        id: EditorXcodeEditorPlugin.id,
        displayName: EditorXcodeEditorPlugin.displayName,
        description: EditorXcodeEditorPlugin.description,
        order: EditorXcodeEditorPlugin.order
    )

    @MainActor
    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        guard context.activeSectionID == editorPanelSectionID,
              context.resolve(LumiEditorServicing.self) != nil
        else {
            return []
        }

        return [
            LumiTitleToolbarItem(
                id: "\(info.id).xcode-scheme",
                title: LumiPluginLocalization.string("Xcode Scheme", bundle: .module),
                placement: .center
            ) {
                XcodeProjectStatusBar()
            }
        ]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.activeSectionID == editorPanelSectionID,
              context.resolve(LumiEditorServicing.self) != nil
        else {
            return []
        }

        return [
            LumiStatusBarItem(
                id: "\(info.id).xcode",
                title: LumiPluginLocalization.string("Xcode Build Context", bundle: .module),
                systemImage: "hammer.fill",
                placement: .trailing,
                statusBarView: {
                    XcodeStatusBarTrailingView()
                }
            ),
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            AddSwiftPackageTool().asLumiAgentTool(),
            ListSwiftPackagesTool().asLumiAgentTool(),
            GenerateXcodeProjectTool().asLumiAgentTool(),
        ]
    }
}
