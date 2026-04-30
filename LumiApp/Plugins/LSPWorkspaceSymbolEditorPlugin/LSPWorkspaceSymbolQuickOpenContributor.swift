import Foundation

@MainActor
final class LSPWorkspaceSymbolQuickOpenContributor: EditorQuickOpenContributor {
    let id: String = "builtin.lsp.workspace-symbol-quick-open"

    func provideQuickOpenItems(
        query: String,
        state: EditorState
    ) async -> [EditorQuickOpenItemSuggestion] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        await state.workspaceSymbolProvider.searchSymbols(query: trimmedQuery)

        return state.workspaceSymbolProvider
            .filterLocalResults(query: trimmedQuery)
            .prefix(12)
            .map { symbol in
                EditorQuickOpenItemSuggestion(
                    id: "workspace-symbol:\(symbol.name):\(symbol.location.uri):\(symbol.location.range.start.line):\(symbol.location.range.start.character)",
                    sectionTitle: "Symbols",
                    title: symbol.name,
                    subtitle: symbol.containerName ?? symbol.location.uri,
                    systemImage: symbol.iconSymbol,
                    badge: symbol.kindDisplayName,
                    order: 100,
                    isEnabled: true,
                    action: {
                        state.performOpenItem(.workspaceSymbol(symbol))
                    }
                )
            }
    }
}
