import Foundation

@MainActor
public enum EditorCommandRouterBridge {
    public static func registerSuggestions(
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

    public static func commandContext(
        from legacy: EditorCommandContext,
        isEditorActive: Bool,
        isMultiCursor: Bool
    ) -> CommandContext {
        var context = CommandContext()
        context.hasSelection = legacy.hasSelection
        context.languageId = legacy.languageId
        context.line = legacy.line
        context.character = legacy.character
        context.isEditorActive = isEditorActive
        context.isMultiCursor = isMultiCursor
        return context
    }

    public static func suggestionsFromRegistry(
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

    public static func execute(
        id: String,
        in context: CommandContext,
        legacySuggestions: [EditorCommandSuggestion]
    ) -> Bool {
        if CommandRegistry.shared.execute(id: id, context: context) {
            return true
        }

        guard let suggestion = legacySuggestions.first(where: { $0.id == id }), suggestion.isEnabled else {
            return false
        }
        suggestion.action()
        return true
    }
}
