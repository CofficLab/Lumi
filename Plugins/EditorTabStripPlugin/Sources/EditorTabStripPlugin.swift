import LumiCoreKit
import SwiftUI
import AgentToolKit
import EditorService

@MainActor
public enum EditorTabStripBridge {
    public static var editorServiceProvider: ((PluginContext) -> EditorService?)?
}

/// 编辑器 Tab 栏插件
///
/// 作为 Panel Header 提供者，当编辑器面板激活时，
/// 在面板内容上方渲染 Tab 栏。
public actor EditorTabStripPlugin: SuperPlugin {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public nonisolated static let emoji = "📑"
    public static let id: String = "EditorTabStrip"
    public static let displayName: String = String(localized: "Editor Tab Strip", bundle: .module)
    public static let description: String = String(localized: "Tab bar for the editor panel", bundle: .module)
    public static let iconName = "rectangle.topthird.inset.filled"
    public static var category: PluginCategory { .editor }
    public static var order: Int { 88 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = EditorTabStripPlugin()

    // MARK: - UI Contributions

    /// 当编辑器面板激活时，提供 Panel Header 视图
    @MainActor
    public func addPanelHeaderView(context: PluginContext) -> AnyView? {
        // 仅在编辑器面板激活时提供 header
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        guard let service = EditorTabStripBridge.editorServiceProvider?(context) else { return nil }
        return AnyView(EditorTabHeaderView(service: service))
    }

    // MARK: - Agent Tools

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            GetCurrentFileTool(),
            SetCurrentFileTool(),
        ]
    }
}
