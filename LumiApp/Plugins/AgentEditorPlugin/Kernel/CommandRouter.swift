import AppKit
import CodeEditTextView
import Foundation

// MARK: - Command Router
//
// 将旧的 EditorCommandSuggestion 桥接到 CommandRegistry。
//
// 旧的命令体系基于 EditorCommandContributor.provideCommands() 返回数组，
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
        let commands = suggestions.map { suggestion in
            KernelEditorCommand(
                id: suggestion.id,
                title: suggestion.title,
                icon: suggestion.systemImage,
                shortcut: suggestion.shortcut,
                category: category,
                order: suggestion.order,
                enablement: CommandEnablement.custom { _ in suggestion.isEnabled },
                handler: suggestion.action
            )
        }
        CommandRegistry.shared.register(commands)
    }

    /// 从旧 context 创建新的 CommandContext。
    static func commandContext(from legacy: EditorCommandContext, isEditorActive: Bool, isMultiCursor: Bool) -> CommandContext {
        var context = CommandContext()
        context.hasSelection = legacy.hasSelection
        context.languageId = legacy.languageId
        context.line = legacy.line
        context.character = legacy.character
        context.isEditorActive = isEditorActive
        context.isMultiCursor = isMultiCursor
        return context
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
        let commands = CommandRegistry.shared.availableCommands(in: context)
        let filtered = filterCategory.map { cat in
            commands.filter { $0.category == cat }
        } ?? commands

        return filtered.map { command in
            EditorCommandSuggestion(
                id: command.id,
                title: command.title,
                systemImage: command.icon ?? "command",
                category: command.category,
                shortcut: command.shortcut,
                order: command.order,
                isEnabled: command.isEnabled(in: context)
            ) {
                command.handler()
            }
        }
    }

    /// 执行命令（通过 ID），兼容新旧体系。
    static func execute(
        id: String,
        in context: CommandContext,
        legacySuggestions: [EditorCommandSuggestion]
    ) -> Bool {
        // 优先走新 registry
        if CommandRegistry.shared.execute(id: id, context: context) {
            return true
        }

        // Fallback：旧的 editorCommandSuggestions 体系
        guard let suggestion = legacySuggestions.first(where: { $0.id == id }), suggestion.isEnabled else {
            return false
        }
        suggestion.action()
        return true
    }
}
