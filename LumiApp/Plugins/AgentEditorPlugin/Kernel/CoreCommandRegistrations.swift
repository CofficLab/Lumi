import AppKit
import CodeEditTextView
import Foundation
import LanguageServerProtocol

// MARK: - Core Command Registrations
//
// Phase 5: 注册所有核心编辑器命令到 CommandRegistry。

@MainActor
enum CoreCommandRegistrations {

    static func registerAll(in state: EditorState) {
        registerFormatCommands(state: state)
        registerNavigationCommands(state: state)
        registerMultiCursorCommands(state: state)
        registerFindReplaceCommands(state: state)
        registerLSPActionCommands(state: state)
        registerSaveCommands(state: state)
    }

    // MARK: - Format

    private static func registerFormatCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.format-document",
            title: String(localized: "Format Document", table: "LumiEditor"),
            icon: "text.justify",
            category: "format"
        ) {
            Task { @MainActor in
                await state.formatDocumentWithLSP()
            }
        })
    }

    // MARK: - Navigation

    private static func registerNavigationCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.find-references",
            title: String(localized: "Find All References", table: "LumiEditor"),
            icon: "magnifyingglass",
            category: "navigation"
        ) {
            Task { @MainActor in
                await state.showReferencesFromCurrentCursor()
            }
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.rename-symbol",
            title: String(localized: "Rename Symbol", table: "LumiEditor"),
            icon: "pencil",
            category: "navigation"
        ) {
            state.promptRenameSymbol()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.workspace-symbols",
            title: String(localized: "Go to Symbol in Workspace", table: "LumiEditor"),
            icon: "text.magnifyingglass",
            category: "navigation"
        ) {
            state.performPanelCommand(.openWorkspaceSymbolSearch)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.call-hierarchy",
            title: String(localized: "Show Call Hierarchy", table: "LumiEditor"),
            icon: "list.bullet",
            category: "navigation"
        ) {
            Task { @MainActor in
                await state.openCallHierarchy()
            }
        })
    }

    // MARK: - Multi-Cursor

    private static func registerMultiCursorCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.add-next-occurrence",
            title: String(localized: "Add Next Occurrence", table: "LumiEditor"),
            icon: "plus.magnifyingglass",
            category: "multi-cursor",
            enablement: .whenTrue(.hasSelection)
        ) {
            state.addNextOccurrence()
        })

        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.select-all-occurrences",
            title: String(localized: "Select All Occurrences", table: "LumiEditor"),
            icon: "text.magnifyingglass",
            category: "multi-cursor",
            enablement: .whenTrue(.hasSelection)
        ) {
            guard let textView = state.focusedTextView else { return }
            let currentSelection = textView.selectionManager.textSelections.last?.range
                ?? NSRange(location: NSNotFound, length: 0)
            _ = state.addAllOccurrences(from: currentSelection)
        })

        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.clear-additional-cursors",
            title: String(localized: "Clear Additional Cursors", table: "LumiEditor"),
            icon: "cursorarrow.motionlines",
            category: "multi-cursor",
            enablement: .whenTrue(.isMultiCursor)
        ) {
            state.clearMultiCursors()
        })
    }

    // MARK: - Find/Replace

    private static func registerFindReplaceCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.find",
            title: String(localized: "Find", table: "LumiEditor"),
            icon: "magnifyingglass",
            category: "find"
        ) {
            state.performPanelCommand(.toggleProblems)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.find-next",
            title: String(localized: "Find Next", table: "LumiEditor"),
            icon: "arrow.down",
            category: "find",
            enablement: CommandEnablement.whenTrue(.isEditorActive)
        ) {
            state.selectNextFindMatch()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.find-previous",
            title: String(localized: "Find Previous", table: "LumiEditor"),
            icon: "arrow.up",
            category: "find",
            enablement: CommandEnablement.whenTrue(.isEditorActive)
        ) {
            state.selectPreviousFindMatch()
        })
    }

    // MARK: - LSP Actions

    private static func registerLSPActionCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.trigger-completion",
            title: String(localized: "Trigger Completion", table: "LumiEditor"),
            icon: "text.badge.plus",
            category: "lsp"
        ) {
            NotificationCenter.default.post(name: .lumiEditorTriggerCompletion, object: nil)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.trigger-parameter-hints",
            title: String(localized: "Trigger Parameter Hints", table: "LumiEditor"),
            icon: "bubble.left",
            category: "lsp"
        ) {
            NotificationCenter.default.post(name: .lumiEditorTriggerSignatureHelp, object: nil)
        })
    }

    // MARK: - Save

    private static func registerSaveCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.save",
            title: String(localized: "Save", table: "LumiEditor"),
            icon: "square.and.arrow.down",
            category: "save",
            enablement: .custom { _ in state.hasUnsavedChanges }
        ) {
            state.saveNow()
        })
    }
}
