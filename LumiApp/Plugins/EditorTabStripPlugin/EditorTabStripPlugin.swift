import LumiCoreKit
import SwiftUI
import AgentToolKit

/// 编辑器 Tab 栏插件
///
/// 作为 Panel Header 提供者，当编辑器面板激活时，
/// 在面板内容上方渲染 Tab 栏。
actor EditorTabStripPlugin: SuperPlugin {
    nonisolated static let emoji = "📑"
    static let id: String = "EditorTabStrip"
    static let displayName: String = String(localized: "Editor Tab Strip", table: "EditorTabStrip")
    static let description: String = String(
        localized: "Tab bar for the editor panel", table: "EditorTabStrip")
    static let iconName = "rectangle.topthird.inset.filled"
    static var category: PluginCategory { .editor }
    static var order: Int { 88 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = EditorTabStripPlugin()

    // MARK: - UI Contributions

    /// 当编辑器面板激活时，提供 Panel Header 视图
    @MainActor
    func addPanelHeaderView(context: PluginContext) -> AnyView? {
        // 仅在编辑器面板激活时提供 header
        guard context.activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(EditorTabHeaderView())
    }

    // MARK: - Agent Tools

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            GetCurrentFileTool(),
            SetCurrentFileTool(),
        ]
    }
}
