import Foundation
import EditorService
import SuperLogKit
import os
import LumiCoreKit

@MainActor
public final class EditorLSPContextCommandContributor: SuperEditorCommandContributor, SuperLog {
    public nonisolated static let emoji = "🔌"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "editor.lsp.context-commands")

    public let id: String = "builtin.lsp.context-commands"

    public func provideCommands(
        context: EditorCommandContext,
        state: EditorState,
        textView: TextView?
    ) -> [EditorCommandSuggestion] {
        let selection = textView?.selectionManager.textSelections.first?.range ?? NSRange(location: 0, length: 0)
        if Self.verbose {
            Self.logger.info("\(Self.t)provideCommands 被调用, canPreview=\(state.canPreview), isEditable=\(state.isEditable), textView=\(textView != nil)")
        }

        return [
            // TODO: 暂时停用以下右键菜单命令
            // .init(
            //     id: "builtin.rename-symbol",
            //     title: LumiPluginLocalization.string("Rename Symbol", bundle: .module),
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
            //     title: LumiPluginLocalization.string("Quick Fix", bundle: .module),
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
                title: LumiPluginLocalization.string("Go to Definition", bundle: .module),
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
            //     title: LumiPluginLocalization.string("Peek Definition", bundle: .module),
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
            //     title: LumiPluginLocalization.string("Go to Declaration", bundle: .module),
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
            //     title: LumiPluginLocalization.string("Go to Type Definition", bundle: .module),
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
            //     title: LumiPluginLocalization.string("Go to Implementation", bundle: .module),
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
            //     title: LumiPluginLocalization.string("Find References", bundle: .module),
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
            //     title: LumiPluginLocalization.string("Peek References", bundle: .module),
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
            //     title: LumiPluginLocalization.string("Format Document", bundle: .module),
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
            //     title: LumiPluginLocalization.string("Workspace Symbols", bundle: .module),
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
            //     title: LumiPluginLocalization.string("Call Hierarchy", bundle: .module),
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
            //     title: LumiPluginLocalization.string("Toggle Problems", bundle: .module),
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
