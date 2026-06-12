import Foundation
import Combine
import EditorCodeEditTextView

@MainActor
final class EditorCommandController {
    func observeCustomBindings(
        store: EditorKeybindingStore = .shared,
        onRefresh: @escaping @MainActor () -> Void
    ) -> AnyCancellable {
        store.$customBindings
            .dropFirst()
            .sink { _ in
                onRefresh()
            }
    }

    func refreshCoreCommandRegistrations(in state: EditorState) {
        CoreCommandRegistrations.registerAll(in: state)
    }

    func commandSuggestions(
        state: EditorState,
        registryContext: CommandContext,
        legacySuggestions: [EditorCommandSuggestion]
    ) -> [EditorCommandSuggestion] {
        let registrySuggestions = CommandRouter.suggestionsFromRegistry(in: registryContext)
        return EditorCommandSuggestionPolicy.deduplicatingSuggestions(registrySuggestions + legacySuggestions)
    }

    func commandSuggestions(
        state: EditorState,
        registryContext: CommandContext,
        legacyContext: EditorCommandContext,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        let legacySuggestions = state.editorExtensions.commandSuggestions(
            for: legacyContext,
            state: state,
            textView: textView
        )
        return commandSuggestions(
            state: state,
            registryContext: registryContext,
            legacySuggestions: legacySuggestions
        )
    }

    func presentationModel(
        from suggestions: [EditorCommandSuggestion],
        recentCommandIDs: [String],
        commandUsageCounts: [String: Int] = [:],
        query: String = "",
        categories: Set<EditorCommandCategory>? = nil
    ) -> EditorCommandPresentationModel {
        EditorCommandPresentationModel.build(
            from: suggestions,
            recentCommandIDs: recentCommandIDs,
            commandUsageCounts: commandUsageCounts,
            query: query,
            allowedCategories: categories
        )
    }

    func executeCommand(
        id: String,
        registryContext: CommandContext,
        legacySuggestions: [EditorCommandSuggestion]
    ) -> Bool {
        CommandRouter.execute(
            id: id,
            in: registryContext,
            legacySuggestions: legacySuggestions
        )
    }

    func recordExecution(
        id: String,
        recentCommandIDs: inout [String],
        commandUsageCounts: inout [String: Int]
    ) {
        EditorCommandSuggestionPolicy.recordExecution(
            id: id,
            recentCommandIDs: &recentCommandIDs,
            commandUsageCounts: &commandUsageCounts
        )
    }
}
