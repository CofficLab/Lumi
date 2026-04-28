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
        registerWorkbenchCommands()
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
            shortcut: EditorCommandBindings.formatDocument.kernelShortcut,
            category: EditorCommandCategory.format.rawValue,
            order: 500
        ) {
            Task { @MainActor in
                await state.formatDocumentWithLSP()
            }
        })
    }

    // MARK: - Navigation

    private static func registerNavigationCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.open-editors-panel",
            title: String(localized: "Open Editors", table: "LumiEditor"),
            icon: "sidebar.left",
            shortcut: EditorCommandBindings.openEditors.kernelShortcut,
            category: EditorCommandCategory.navigation.rawValue,
            order: 200
        ) {
            state.performPanelCommand(.toggleOpenEditors)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.find-references",
            title: String(localized: "Find All References", table: "LumiEditor"),
            icon: "magnifyingglass",
            shortcut: EditorCommandBindings.findReferences.kernelShortcut,
            category: EditorCommandCategory.navigation.rawValue,
            order: 510
        ) {
            Task { @MainActor in
                await state.showReferencesFromCurrentCursor()
            }
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.rename-symbol",
            title: String(localized: "Rename Symbol", table: "LumiEditor"),
            icon: "pencil",
            shortcut: EditorCommandBindings.renameSymbol.kernelShortcut,
            category: EditorCommandCategory.navigation.rawValue,
            order: 520
        ) {
            state.promptRenameSymbol()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.workspace-symbols",
            title: String(localized: "Go to Symbol in Workspace", table: "LumiEditor"),
            icon: "text.magnifyingglass",
            shortcut: EditorCommandBindings.workspaceSymbols.kernelShortcut,
            category: EditorCommandCategory.navigation.rawValue,
            order: 530
        ) {
            state.performPanelCommand(.openWorkspaceSymbolSearch)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.call-hierarchy",
            title: String(localized: "Show Call Hierarchy", table: "LumiEditor"),
            icon: "list.bullet",
            shortcut: EditorCommandBindings.callHierarchy.kernelShortcut,
            category: EditorCommandCategory.navigation.rawValue,
            order: 540
        ) {
            Task { @MainActor in
                await state.openCallHierarchy()
            }
        })
    }

    // MARK: - Workbench

    private static func registerWorkbenchCommands() {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.command-palette",
            title: String(localized: "Command Palette", table: "LumiEditor"),
            icon: "command",
            shortcut: EditorCommandBindings.commandPalette.kernelShortcut,
            category: EditorCommandCategory.workbench.rawValue,
            order: 100
        ) {
            NotificationCenter.postLumiEditorShowCommandPalette()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.split-right",
            title: String(localized: "Split Editor Right", table: "LumiEditor"),
            icon: "rectangle.split.2x1",
            shortcut: EditorCommandBindings.splitRight.kernelShortcut,
            category: EditorCommandCategory.workbench.rawValue,
            order: 110
        ) {
            NotificationCenter.postLumiEditorSplitRight()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.split-down",
            title: String(localized: "Split Editor Down", table: "LumiEditor"),
            icon: "rectangle.split.1x2",
            shortcut: EditorCommandBindings.splitDown.kernelShortcut,
            category: EditorCommandCategory.workbench.rawValue,
            order: 120
        ) {
            NotificationCenter.postLumiEditorSplitDown()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.close-split",
            title: String(localized: "Close Split Editor", table: "LumiEditor"),
            icon: "rectangle.compress.vertical",
            shortcut: EditorCommandBindings.closeSplit.kernelShortcut,
            category: EditorCommandCategory.workbench.rawValue,
            order: 130
        ) {
            NotificationCenter.postLumiEditorCloseSplit()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.focus-next-group",
            title: String(localized: "Focus Next Editor Group", table: "LumiEditor"),
            icon: "arrow.right.to.line",
            shortcut: EditorCommandBindings.focusNextGroup.kernelShortcut,
            category: EditorCommandCategory.workbench.rawValue,
            order: 140
        ) {
            NotificationCenter.postLumiEditorFocusNextGroup()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.focus-previous-group",
            title: String(localized: "Focus Previous Editor Group", table: "LumiEditor"),
            icon: "arrow.left.to.line",
            shortcut: EditorCommandBindings.focusPreviousGroup.kernelShortcut,
            category: EditorCommandCategory.workbench.rawValue,
            order: 150
        ) {
            NotificationCenter.postLumiEditorFocusPreviousGroup()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.move-to-next-group",
            title: String(localized: "Move Editor to Next Group", table: "LumiEditor"),
            icon: "arrow.right.square",
            shortcut: EditorCommandBindings.moveToNextGroup.kernelShortcut,
            category: EditorCommandCategory.workbench.rawValue,
            order: 160
        ) {
            NotificationCenter.postLumiEditorMoveToNextGroup()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.move-to-previous-group",
            title: String(localized: "Move Editor to Previous Group", table: "LumiEditor"),
            icon: "arrow.left.square",
            shortcut: EditorCommandBindings.moveToPreviousGroup.kernelShortcut,
            category: EditorCommandCategory.workbench.rawValue,
            order: 170
        ) {
            NotificationCenter.postLumiEditorMoveToPreviousGroup()
        })
    }

    // MARK: - Multi-Cursor

    private static func registerMultiCursorCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.add-next-occurrence",
            title: String(localized: "Add Next Occurrence", table: "LumiEditor"),
            icon: "plus.magnifyingglass",
            category: EditorCommandCategory.multiCursor.rawValue,
            order: 600,
            enablement: .whenTrue(.hasSelection)
        ) {
            state.addNextOccurrence()
        })

        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.select-all-occurrences",
            title: String(localized: "Select All Occurrences", table: "LumiEditor"),
            icon: "text.magnifyingglass",
            category: EditorCommandCategory.multiCursor.rawValue,
            order: 610,
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
            category: EditorCommandCategory.multiCursor.rawValue,
            order: 620,
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
            shortcut: EditorCommandBindings.find.kernelShortcut,
            category: EditorCommandCategory.find.rawValue,
            order: 400
        ) {
            state.toggleFindPanel()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.find-next",
            title: String(localized: "Find Next", table: "LumiEditor"),
            icon: "arrow.down",
            shortcut: EditorCommandBindings.findNext.kernelShortcut,
            category: EditorCommandCategory.find.rawValue,
            order: 410,
            enablement: CommandEnablement.whenTrue(.isEditorActive)
        ) {
            state.selectNextFindMatch()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.find-previous",
            title: String(localized: "Find Previous", table: "LumiEditor"),
            icon: "arrow.up",
            shortcut: EditorCommandBindings.findPrevious.kernelShortcut,
            category: EditorCommandCategory.find.rawValue,
            order: 420,
            enablement: CommandEnablement.whenTrue(.isEditorActive)
        ) {
            state.selectPreviousFindMatch()
        })

        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.replace-current",
            title: String(localized: "Replace", table: "LumiEditor"),
            icon: "arrow.triangle.2.circlepath",
            category: EditorCommandCategory.find.rawValue,
            order: 430,
            enablement: .custom { _ in state.activeSession.findReplaceState.selectedMatchIndex != nil }
        ) {
            state.replaceCurrentFindMatch()
        })

        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.replace-all",
            title: String(localized: "Replace All", table: "LumiEditor"),
            icon: "square.stack.3d.up",
            category: EditorCommandCategory.find.rawValue,
            order: 440,
            enablement: .custom { _ in !state.findMatches.isEmpty }
        ) {
            state.replaceAllFindMatches()
        })
    }

    // MARK: - LSP Actions

    private static func registerLSPActionCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.trigger-completion",
            title: String(localized: "Trigger Completion", table: "LumiEditor"),
            icon: "text.badge.plus",
            category: EditorCommandCategory.lsp.rawValue,
            order: 700
        ) {
            NotificationCenter.default.post(name: .lumiEditorTriggerCompletion, object: nil)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.trigger-parameter-hints",
            title: String(localized: "Trigger Parameter Hints", table: "LumiEditor"),
            icon: "bubble.left",
            category: EditorCommandCategory.lsp.rawValue,
            order: 710
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
            category: EditorCommandCategory.save.rawValue,
            order: 800,
            enablement: .custom { _ in state.hasUnsavedChanges }
        ) {
            state.saveNow()
        })
    }
}
