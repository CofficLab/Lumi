import Foundation
import EditorService
import SuperLogKit
import CodeEditTextView
import os

@MainActor
public final class EditorLSPContextCommandContributor: SuperEditorCommandContributor, SuperLog {
    public nonisolated static let emoji = "🔌"
    public nonisolated static let verbose: Bool = true

    public let id: String = "builtin.lsp.context-commands"

    public func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        let selection = textView?.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)
        if Self.verbose {
            if EditorLSPContextCommandsPlugin.verbose {
                            EditorLSPContextCommandsPlugin.logger.info("\(self.t)provideCommands 被调用, canPreview=\(state.canPreview), isEditable=\(state.isEditable), textView=\(textView != nil)")
            }
        }

        return [
            // TODO: 暂时停用以下右键菜单命令
            // .init(
            //     id: "builtin.rename-symbol",
            //     title: String(localized: "Rename Symbol", table: "EditorLSPContextCommands"),
            //     systemImage: "pencil.and.list.clipboard",
            //     category: EditorCommandCategory.navigation.rawValue,
            //     order: 10,
            //     isEnabled: state.canPreview && state.isEditable,
            //     action: {
            //         state.promptRenameSymbol()
            //     }
            // ),
            // .init(
            //     id: "builtin.quick-fix",
            //     title: String(localized: "Quick Fix", table: "LumiEditor"),
            //     systemImage: "lightbulb",
            //     category: EditorCommandCategory.navigation.rawValue,
            //     order: 15,
            //     isEnabled: state.canPreview && state.isEditable,
            //     action: {
            //         Task { @MainActor in
            //             await state.showQuickFixesFromCurrentCursor()
            //         }
            //     }
            // ),
            .init(
                id: "builtin.go-to-definition",
                title: String(localized: "Go to Definition", table: "EditorLSPContextCommands"),
                systemImage: "arrow.right.square",
                category: EditorCommandCategory.navigation.rawValue,
                order: 20,
                isEnabled: true,
                action: {
                    Task { @MainActor in
                        await state.goToDefinition(for: selection)
                    }
                }
            ),
            // .init(
            //     id: "builtin.peek-definition",
            //     title: String(localized: "Peek Definition", table: "LumiEditor"),
            //     systemImage: "arrow.turn.down.right",
            //     category: EditorCommandCategory.navigation.rawValue,
            //     order: 25,
            //     isEnabled: state.canPreview,
            //     action: {
            //         Task { @MainActor in
            //             await state.showPeekDefinitionFromCurrentCursor()
            //         }
            //     }
            // ),
            // .init(
            //     id: "builtin.go-to-declaration",
            //     title: String(localized: "Go to Declaration", table: "EditorLSPContextCommands"),
            //     systemImage: "doc.badge.plus",
            //     category: EditorCommandCategory.navigation.rawValue,
            //     order: 30,
            //     isEnabled: true,
            //     action: {
            //         Task { @MainActor in
            //             await state.goToDeclaration(for: selection)
            //         }
            //     }
            // ),
            // .init(
            //     id: "builtin.go-to-type-definition",
            //     title: String(localized: "Go to Type Definition", table: "EditorLSPContextCommands"),
            //     systemImage: "square.on.square",
            //     category: EditorCommandCategory.navigation.rawValue,
            //     order: 40,
            //     isEnabled: true,
            //     action: {
            //         Task { @MainActor in
            //             await state.goToTypeDefinition(for: selection)
            //         }
            //     }
            // ),
            // .init(
            //     id: "builtin.go-to-implementation",
            //     title: String(localized: "Go to Implementation", table: "EditorLSPContextCommands"),
            //     systemImage: "arrowtriangle.right",
            //     category: EditorCommandCategory.navigation.rawValue,
            //     order: 50,
            //     isEnabled: true,
            //     action: {
            //         Task { @MainActor in
            //             await state.goToImplementation(for: selection)
            //         }
            //     }
            // ),
            // .init(
            //     id: "builtin.find-references",
            //     title: String(localized: "Find References", table: "EditorLSPContextCommands"),
            //     systemImage: "link",
            //     category: EditorCommandCategory.navigation.rawValue,
            //     order: 60,
            //     isEnabled: state.canPreview,
            //     action: {
            //         Task { @MainActor in
            //             await state.showReferencesFromCurrentCursor()
            //         }
            //     }
            // ),
            // .init(
            //     id: "builtin.peek-references",
            //     title: String(localized: "Peek References", table: "LumiEditor"),
            //     systemImage: "arrow.triangle.branch",
            //     category: EditorCommandCategory.navigation.rawValue,
            //     order: 65,
            //     isEnabled: state.canPreview,
            //     action: {
            //         Task { @MainActor in
            //             await state.showPeekReferencesFromCurrentCursor()
            //         }
            //     }
            // ),
            // .init(
            //     id: "builtin.format-document",
            //     title: String(localized: "Format Document", table: "EditorLSPContextCommands"),
            //     systemImage: "text.alignleft",
            //     category: EditorCommandCategory.format.rawValue,
            //     order: 70,
            //     isEnabled: state.canPreview && state.isEditable,
            //     action: {
            //         Task { @MainActor in
            //             await state.formatDocumentWithLSP()
            //         }
            //     }
            // ),
            // .init(
            //     id: "builtin.workspace-symbols",
            //     title: String(localized: "Workspace Symbols", table: "EditorLSPContextCommands"),
            //     systemImage: "magnifyingglass.circle",
            //     category: EditorCommandCategory.navigation.rawValue,
            //     order: 80,
            //     isEnabled: state.canPreview,
            //     action: {
            //         state.performPanelCommand(.openWorkspaceSymbolSearch)
            //     }
            // ),
            // .init(
            //     id: "builtin.call-hierarchy",
            //     title: String(localized: "Call Hierarchy", table: "EditorLSPContextCommands"),
            //     systemImage: "arrow.triangle.branch",
            //     category: EditorCommandCategory.navigation.rawValue,
            //     order: 90,
            //     isEnabled: state.canPreview,
            //     action: {
            //         Task { @MainActor in
            //             await state.openCallHierarchy()
            //         }
            //     }
            // ),
            // .init(
            //     id: "builtin.toggle-problems",
            //     title: String(localized: "Toggle Problems", table: "EditorLSPContextCommands"),
            //     systemImage: "exclamationmark.triangle",
            //     category: EditorCommandCategory.lsp.rawValue,
            //     order: 100,
            //     isEnabled: true,
            //     action: {
            //         state.performPanelCommand(.toggleProblems)
            //     }
            // )
        ]
    }
}
