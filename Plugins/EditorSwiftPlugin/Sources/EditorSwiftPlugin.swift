import AgentToolKit
import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

/// Swift / Xcode 集成插件：scheme 工具栏、构建上下文状态栏与 Agent 工具。
public enum EditorSwiftPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .development
    public static let iconName = "swift"

    /// Code Editor 面板 section id（与 `EditorPanelPlugin.info.id` 一致）。
    private static let editorPanelSectionID = "LumiEditor"

    public static let info = LumiPluginInfo(
        id: EditorSwiftEditorPlugin.id,
        displayName: EditorSwiftEditorPlugin.displayName,
        description: EditorSwiftEditorPlugin.description,
        order: EditorSwiftEditorPlugin.order
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
                placement: .leading
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
