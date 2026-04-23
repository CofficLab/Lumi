import Foundation
import CodeEditTextView

@objc(LumiLSPContextCommandsEditorPlugin)
@MainActor
final class LSPContextCommandsEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.context-commands"
    let displayName: String = "LSP Context Commands"
    let order: Int = 15

    func register(into registry: EditorExtensionRegistry) {
        registry.registerCommandContributor(LSPContextCommandContributor())
    }
}

@MainActor
final class LSPContextCommandContributor: EditorCommandContributor {
    let id: String = "builtin.lsp.context-commands"

    func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        let selection = textView?.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)

        return [
            .init(
                id: "builtin.rename-symbol",
                title: String(localized: "Rename Symbol", table: "LumiEditor"),
                systemImage: "pencil.and.list.clipboard",
                order: 10,
                isEnabled: state.canPreview && state.isEditable,
                action: {
                    state.promptRenameSymbol()
                }
            ),
            .init(
                id: "builtin.go-to-definition",
                title: String(localized: "Go to Definition", table: "LumiEditor"),
                systemImage: "arrow.right.square",
                order: 20,
                isEnabled: true,
                action: {
                    Task { @MainActor in
                        await state.goToDefinition(for: selection)
                    }
                }
            ),
            .init(
                id: "builtin.go-to-declaration",
                title: String(localized: "Go to Declaration", table: "LumiEditor"),
                systemImage: "doc.badge.plus",
                order: 30,
                isEnabled: true,
                action: {
                    Task { @MainActor in
                        await state.goToDeclaration(for: selection)
                    }
                }
            ),
            .init(
                id: "builtin.go-to-type-definition",
                title: String(localized: "Go to Type Definition", table: "LumiEditor"),
                systemImage: "square.on.square",
                order: 40,
                isEnabled: true,
                action: {
                    Task { @MainActor in
                        await state.goToTypeDefinition(for: selection)
                    }
                }
            ),
            .init(
                id: "builtin.go-to-implementation",
                title: String(localized: "Go to Implementation", table: "LumiEditor"),
                systemImage: "arrowtriangle.right",
                order: 50,
                isEnabled: true,
                action: {
                    Task { @MainActor in
                        await state.goToImplementation(for: selection)
                    }
                }
            ),
            .init(
                id: "builtin.find-references",
                title: String(localized: "Find References", table: "LumiEditor"),
                systemImage: "link",
                order: 60,
                isEnabled: state.canPreview,
                action: {
                    Task { @MainActor in
                        await state.showReferencesFromCurrentCursor()
                    }
                }
            ),
            .init(
                id: "builtin.format-document",
                title: String(localized: "Format Document", table: "LumiEditor"),
                systemImage: "text.alignleft",
                order: 70,
                isEnabled: state.canPreview && state.isEditable,
                action: {
                    Task { @MainActor in
                        await state.formatDocumentWithLSP()
                    }
                }
            ),
            .init(
                id: "builtin.workspace-symbols",
                title: "Workspace Symbols",
                systemImage: "magnifyingglass.circle",
                order: 80,
                isEnabled: state.canPreview,
                action: {
                    state.openWorkspaceSymbolSearch()
                }
            ),
            .init(
                id: "builtin.call-hierarchy",
                title: "Call Hierarchy",
                systemImage: "arrow.triangle.branch",
                order: 90,
                isEnabled: state.canPreview,
                action: {
                    Task { @MainActor in
                        await state.openCallHierarchy()
                    }
                }
            ),
            .init(
                id: "builtin.toggle-problems",
                title: String(localized: "Toggle Problems", table: "LumiEditor"),
                systemImage: "exclamationmark.triangle",
                order: 100,
                isEnabled: true,
                action: {
                    state.toggleProblemsPanel()
                }
            )
        ]
    }
}
