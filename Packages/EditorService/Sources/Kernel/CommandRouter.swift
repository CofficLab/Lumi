import AppKit
import EditorCodeEditTextView
import Foundation

// MARK: - Command Router
//
// 将旧的 EditorCommandSuggestion 桥接到 CommandRegistry。
//
// 旧的命令体系基于 SuperEditorCommandContributor.provideCommands() 返回数组，
// 新的体系基于中央 CommandRegistry。
// CommandRouter 负责在两者之间建立双向兼容。

@MainActor
enum CommandRouter {

    // MARK: - Legacy → Registry

    /// 将旧的 EditorCommandSuggestion 注册到 CommandRegistry。
    static func registerSuggestions(
        _ suggestions: [EditorCommandSuggestion],
        category: String? = nil
    ) {
        EditorCommandRouterBridge.registerSuggestions(
            suggestions,
            category: category
        )
    }

    /// 从旧 context 创建新的 CommandContext。
    static func commandContext(from legacy: EditorCommandContext, isEditorActive: Bool, isMultiCursor: Bool) -> CommandContext {
        EditorCommandRouterBridge.commandContext(
            from: legacy,
            isEditorActive: isEditorActive,
            isMultiCursor: isMultiCursor
        )
    }

    /// 从旧 context 和 state 创建 CommandContext。
    static func commandContext(state: EditorState, legacyContext: EditorCommandContext) -> CommandContext {
        commandContext(
            from: legacyContext,
            isEditorActive: state.currentFileURL != nil,
            isMultiCursor: state.multiCursorState.isEnabled
        )
    }

    // MARK: - Registry → Legacy

    /// 将 CommandRegistry 中的命令转换为旧的 EditorCommandSuggestion 格式。
    static func suggestionsFromRegistry(
        in context: CommandContext,
        filterCategory: String? = nil
    ) -> [EditorCommandSuggestion] {
        EditorCommandRouterBridge.suggestionsFromRegistry(
            in: context,
            filterCategory: filterCategory
        )
    }

    /// 执行命令（通过 ID），兼容新旧体系。
    static func execute(
        id: String,
        in context: CommandContext,
        legacySuggestions: [EditorCommandSuggestion]
    ) -> Bool {
        EditorCommandRouterBridge.execute(
            id: id,
            in: context,
            legacySuggestions: legacySuggestions
        )
    }
}
