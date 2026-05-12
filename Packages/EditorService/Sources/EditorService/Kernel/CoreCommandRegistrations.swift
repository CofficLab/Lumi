import AppKit
import CodeEditTextView
import Foundation
import LanguageServerProtocol

// MARK: - Core Command Registrations
//
// Phase 5: 注册所有核心编辑器命令到 CommandRegistry。

@MainActor
enum CoreCommandRegistrations {

    /// 解析命令的实际快捷键（用户自定义优先，否则默认）
    private static func resolveShortcut(
        _ binding: EditorCommandBinding,
        for commandID: String
    ) -> EditorCommandShortcut {
        binding.resolveKernelShortcut(for: commandID)
    }

    static func registerAll(in state: EditorState) {
        registerHistoryCommands(state: state)
        registerFormatCommands(state: state)
        registerNavigationCommands(state: state)
        registerWorkbenchCommands()
        registerMultiCursorCommands(state: state)
        registerFindReplaceCommands(state: state)
        registerLSPActionCommands(state: state)
        registerSaveCommands(state: state)
        registerLineEditingCommands(state: state)
        registerCursorMotionCommands(state: state)
        registerFoldingCommands(state: state)
    }

    // MARK: - Format

    private static func registerHistoryCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.undo",
            title: String(localized: "Undo", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.uturn.backward",
            shortcut: resolveShortcut(EditorCommandBindings.undo, for: "builtin.undo"),
            category: EditorCommandCategory.other.rawValue,
            order: 50,
            enablement: .custom { _ in state.canUndo }
        ) {
            state.performUndo()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.redo",
            title: String(localized: "Redo", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.uturn.forward",
            shortcut: resolveShortcut(EditorCommandBindings.redo, for: "builtin.redo"),
            category: EditorCommandCategory.other.rawValue,
            order: 60,
            enablement: .custom { _ in state.canRedo }
        ) {
            state.performRedo()
        })
    }

    // MARK: - Format

    private static func registerFormatCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.format-document",
            title: String(localized: "Format Document", table: EditorHostEnvironment.current.localizationTable),
            icon: "text.justify",
            shortcut: resolveShortcut(EditorCommandBindings.formatDocument, for: "builtin.format-document"),
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
            title: String(localized: "Open Editors", table: EditorHostEnvironment.current.localizationTable),
            icon: "sidebar.left",
            shortcut: resolveShortcut(EditorCommandBindings.openEditors, for: "builtin.open-editors-panel"),
            category: EditorCommandCategory.navigation.rawValue,
            order: 200
        ) {
            NotificationCenter.default.post(name: EditorHostEnvironment.current.notifications.toggleOpenEditorsPanel, object: nil)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.outline-panel",
            title: String(localized: "Outline", table: EditorHostEnvironment.current.localizationTable),
            icon: "list.bullet.indent",
            shortcut: nil,
            category: EditorCommandCategory.navigation.rawValue,
            order: 205
        ) {
            NotificationCenter.default.post(name: EditorHostEnvironment.current.notifications.toggleOutlinePanel, object: nil)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.find-references",
            title: String(localized: "Find All References", table: EditorHostEnvironment.current.localizationTable),
            icon: "magnifyingglass",
            shortcut: resolveShortcut(EditorCommandBindings.findReferences, for: "builtin.find-references"),
            category: EditorCommandCategory.navigation.rawValue,
            order: 510
        ) {
            Task { @MainActor in
                await state.showReferencesFromCurrentCursor()
            }
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.quick-fix",
            title: String(localized: "Quick Fix", table: EditorHostEnvironment.current.localizationTable),
            icon: "lightbulb",
            shortcut: resolveShortcut(EditorCommandBindings.quickFix, for: "builtin.quick-fix"),
            category: EditorCommandCategory.navigation.rawValue,
            order: 512,
            enablement: .custom { _ in state.canPreview && state.isEditable }
        ) {
            Task { @MainActor in
                await state.showQuickFixesFromCurrentCursor()
            }
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.peek-references",
            title: String(localized: "Peek References", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.triangle.branch",
            category: EditorCommandCategory.navigation.rawValue,
            order: 515
        ) {
            Task { @MainActor in
                await state.showPeekReferencesFromCurrentCursor()
            }
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.rename-symbol",
            title: String(localized: "Rename Symbol", table: EditorHostEnvironment.current.localizationTable),
            icon: "pencil",
            shortcut: resolveShortcut(EditorCommandBindings.renameSymbol, for: "builtin.rename-symbol"),
            category: EditorCommandCategory.navigation.rawValue,
            order: 520
        ) {
            state.promptRenameSymbol()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.peek-definition",
            title: String(localized: "Peek Definition", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.turn.down.right",
            category: EditorCommandCategory.navigation.rawValue,
            order: 525
        ) {
            Task { @MainActor in
                await state.showPeekDefinitionFromCurrentCursor()
            }
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.workspace-symbols",
            title: String(localized: "Go to Symbol in Workspace", table: EditorHostEnvironment.current.localizationTable),
            icon: "text.magnifyingglass",
            shortcut: resolveShortcut(EditorCommandBindings.workspaceSymbols, for: "builtin.workspace-symbols"),
            category: EditorCommandCategory.navigation.rawValue,
            order: 530
        ) {
            state.performPanelCommand(.openWorkspaceSymbolSearch)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.call-hierarchy",
            title: String(localized: "Show Call Hierarchy", table: EditorHostEnvironment.current.localizationTable),
            icon: "list.bullet",
            shortcut: resolveShortcut(EditorCommandBindings.callHierarchy, for: "builtin.call-hierarchy"),
            category: EditorCommandCategory.navigation.rawValue,
            order: 540
        ) {
            Task { @MainActor in
                await state.openCallHierarchy()
            }
        })
    }

    private static func registerFoldingCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.fold-current",
            title: String(localized: "Fold Current Block", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.up.left.and.arrow.down.right",
            category: EditorCommandCategory.navigation.rawValue,
            order: 560,
            enablement: .custom { _ in state.showFoldingRibbon && !state.largeFileMode.isFoldingDisabled }
        ) {
            state.collapseCurrentFold()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.unfold-current",
            title: String(localized: "Unfold Current Block", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.down.right.and.arrow.up.left",
            category: EditorCommandCategory.navigation.rawValue,
            order: 561,
            enablement: .custom { _ in state.showFoldingRibbon && !state.largeFileMode.isFoldingDisabled }
        ) {
            state.expandCurrentFold()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.fold-all",
            title: String(localized: "Fold All", table: EditorHostEnvironment.current.localizationTable),
            icon: "rectangle.compress.vertical",
            category: EditorCommandCategory.navigation.rawValue,
            order: 562,
            enablement: .custom { _ in state.showFoldingRibbon && !state.largeFileMode.isFoldingDisabled }
        ) {
            state.collapseAllFolds()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.unfold-all",
            title: String(localized: "Unfold All", table: EditorHostEnvironment.current.localizationTable),
            icon: "rectangle.expand.vertical",
            category: EditorCommandCategory.navigation.rawValue,
            order: 563,
            enablement: .custom { _ in state.showFoldingRibbon && !state.largeFileMode.isFoldingDisabled }
        ) {
            state.expandAllFolds()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.fold-level-1",
            title: String(localized: "Fold Level 1", table: EditorHostEnvironment.current.localizationTable),
            icon: "1.circle",
            category: EditorCommandCategory.navigation.rawValue,
            order: 564,
            enablement: .custom { _ in state.showFoldingRibbon && !state.largeFileMode.isFoldingDisabled }
        ) {
            state.collapseFolds(toLevel: 1)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.fold-level-2",
            title: String(localized: "Fold Level 2", table: EditorHostEnvironment.current.localizationTable),
            icon: "2.circle",
            category: EditorCommandCategory.navigation.rawValue,
            order: 565,
            enablement: .custom { _ in state.showFoldingRibbon && !state.largeFileMode.isFoldingDisabled }
        ) {
            state.collapseFolds(toLevel: 2)
        })
    }

    // MARK: - Workbench

    private static func registerWorkbenchCommands() {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.command-palette",
            title: String(localized: "Command Palette", table: EditorHostEnvironment.current.localizationTable),
            icon: "command",
            shortcut: resolveShortcut(EditorCommandBindings.commandPalette, for: "builtin.command-palette"),
            category: EditorCommandCategory.workbench.rawValue,
            order: 100
        ) {
            NotificationCenter.default.post(name: EditorHostEnvironment.current.notifications.showCommandPalette, object: nil)
        })
    }

    // MARK: - Multi-Cursor

    private static func registerMultiCursorCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.add-next-occurrence",
            title: String(localized: "Add Next Occurrence", table: EditorHostEnvironment.current.localizationTable),
            icon: "plus.magnifyingglass",
            category: EditorCommandCategory.multiCursor.rawValue,
            order: 600,
            enablement: .whenTrue(.hasSelection)
        ) {
            state.addNextOccurrence()
            state.focusedTextView?.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
        })

        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.select-all-occurrences",
            title: String(localized: "Select All Occurrences", table: EditorHostEnvironment.current.localizationTable),
            icon: "text.magnifyingglass",
            category: EditorCommandCategory.multiCursor.rawValue,
            order: 610,
            enablement: .whenTrue(.hasSelection)
        ) {
            guard let textView = state.focusedTextView else { return }
            let currentSelection = textView.selectionManager.textSelections.last?.range
                ?? NSRange(location: NSNotFound, length: 0)
            if let ranges = state.addAllOccurrences(from: currentSelection) {
                textView.selectionManager.setSelectedRanges(ranges)
            }
        })

        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.remove-last-occurrence-selection",
            title: String(localized: "Remove Last Occurrence Selection", table: EditorHostEnvironment.current.localizationTable),
            icon: "minus.magnifyingglass",
            category: EditorCommandCategory.multiCursor.rawValue,
            order: 615,
            enablement: .whenTrue(.isMultiCursor)
        ) {
            if let ranges = state.removeLastOccurrenceSelection() {
                state.focusedTextView?.selectionManager.setSelectedRanges(ranges)
            }
        })

        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.clear-additional-cursors",
            title: String(localized: "Clear Additional Cursors", table: EditorHostEnvironment.current.localizationTable),
            icon: "cursorarrow.motionlines",
            category: EditorCommandCategory.multiCursor.rawValue,
            order: 620,
            enablement: .whenTrue(.isMultiCursor)
        ) {
            state.clearMultiCursors()
            state.focusedTextView?.selectionManager.setSelectedRanges(state.currentSelectionsAsNSRanges())
        })
    }

    // MARK: - Find/Replace

    private static func registerFindReplaceCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.find",
            title: String(localized: "Find", table: EditorHostEnvironment.current.localizationTable),
            icon: "magnifyingglass",
            shortcut: resolveShortcut(EditorCommandBindings.find, for: "builtin.find"),
            category: EditorCommandCategory.find.rawValue,
            order: 400
        ) {
            state.toggleFindPanel()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.search-in-files",
            title: String(localized: "Search in Files", table: EditorHostEnvironment.current.localizationTable),
            icon: "doc.text.magnifyingglass",
            shortcut: resolveShortcut(EditorCommandBindings.searchInFiles, for: "builtin.search-in-files"),
            category: EditorCommandCategory.find.rawValue,
            order: 405
        ) {
            state.openWorkspaceSearchPanel()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.find-next",
            title: String(localized: "Find Next", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.down",
            shortcut: resolveShortcut(EditorCommandBindings.findNext, for: "builtin.find-next"),
            category: EditorCommandCategory.find.rawValue,
            order: 410,
            enablement: CommandEnablement.whenTrue(.isEditorActive)
        ) {
            state.selectNextFindMatch()
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.find-previous",
            title: String(localized: "Find Previous", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.up",
            shortcut: resolveShortcut(EditorCommandBindings.findPrevious, for: "builtin.find-previous"),
            category: EditorCommandCategory.find.rawValue,
            order: 420,
            enablement: CommandEnablement.whenTrue(.isEditorActive)
        ) {
            state.selectPreviousFindMatch()
        })

        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.replace-current",
            title: String(localized: "Replace", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.triangle.2.circlepath",
            category: EditorCommandCategory.find.rawValue,
            order: 430,
            enablement: .custom { _ in state.activeSession.findReplaceState.selectedMatchIndex != nil }
        ) {
            state.replaceCurrentFindMatch()
        })

        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.replace-all",
            title: String(localized: "Replace All", table: EditorHostEnvironment.current.localizationTable),
            icon: "square.stack.3d.up",
            category: EditorCommandCategory.find.rawValue,
            order: 440,
            enablement: .custom { _ in !state.findMatches.isEmpty }
        ) {
            state.replaceAllFindMatches()
        })

        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.open-search-editor",
            title: String(localized: "Open Search Editor", table: EditorHostEnvironment.current.localizationTable),
            icon: "doc.plaintext",
            category: EditorCommandCategory.find.rawValue,
            order: 445,
            enablement: .custom { _ in state.panelState.workspaceSearchSummary?.totalMatches ?? 0 > 0 }
        ) {
            state.openWorkspaceSearchResultsInEditor()
        })
    }

    // MARK: - LSP Actions

    private static func registerLSPActionCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.trigger-completion",
            title: String(localized: "Trigger Completion", table: EditorHostEnvironment.current.localizationTable),
            icon: "text.badge.plus",
            category: EditorCommandCategory.lsp.rawValue,
            order: 700
        ) {
            NotificationCenter.default.post(name: EditorHostEnvironment.current.notifications.triggerCompletion, object: nil)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.trigger-parameter-hints",
            title: String(localized: "Trigger Parameter Hints", table: EditorHostEnvironment.current.localizationTable),
            icon: "bubble.left",
            category: EditorCommandCategory.lsp.rawValue,
            order: 710
        ) {
            NotificationCenter.default.post(name: EditorHostEnvironment.current.notifications.triggerSignatureHelp, object: nil)
        })
    }

    // MARK: - Save

    private static func registerSaveCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand(
            id: "builtin.save",
            title: String(localized: "Save", table: EditorHostEnvironment.current.localizationTable),
            icon: "square.and.arrow.down",
            shortcut: resolveShortcut(EditorCommandBindings.save, for: "builtin.save"),
            category: EditorCommandCategory.save.rawValue,
            order: 800,
            enablement: .custom { _ in state.hasUnsavedChanges }
        ) {
            state.saveNow()
        })
    }

    // MARK: - Line Editing (Phase 9)

    private static func registerLineEditingCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.delete-line",
            title: String(localized: "Delete Line", table: EditorHostEnvironment.current.localizationTable),
            icon: "trash",
            shortcut: resolveShortcut(EditorCommandBindings.deleteLine, for: "builtin.delete-line"),
            category: EditorCommandCategory.edit.rawValue,
            order: 900
        ) {
            state.performLineEdit(.deleteLine)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.copy-line-down",
            title: String(localized: "Copy Line Down", table: EditorHostEnvironment.current.localizationTable),
            icon: "doc.on.doc",
            shortcut: resolveShortcut(EditorCommandBindings.copyLineDown, for: "builtin.copy-line-down"),
            category: EditorCommandCategory.edit.rawValue,
            order: 910
        ) {
            state.performLineEdit(.copyLineDown)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.copy-line-up",
            title: String(localized: "Copy Line Up", table: EditorHostEnvironment.current.localizationTable),
            icon: "doc.on.doc",
            shortcut: resolveShortcut(EditorCommandBindings.copyLineUp, for: "builtin.copy-line-up"),
            category: EditorCommandCategory.edit.rawValue,
            order: 920
        ) {
            state.performLineEdit(.copyLineUp)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.move-line-down",
            title: String(localized: "Move Line Down", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.down",
            shortcut: resolveShortcut(EditorCommandBindings.moveLineDown, for: "builtin.move-line-down"),
            category: EditorCommandCategory.edit.rawValue,
            order: 930
        ) {
            state.performLineEdit(.moveLineDown)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.move-line-up",
            title: String(localized: "Move Line Up", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.up",
            shortcut: resolveShortcut(EditorCommandBindings.moveLineUp, for: "builtin.move-line-up"),
            category: EditorCommandCategory.edit.rawValue,
            order: 940
        ) {
            state.performLineEdit(.moveLineUp)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.insert-line-below",
            title: String(localized: "Insert Line Below", table: EditorHostEnvironment.current.localizationTable),
            icon: "text.append",
            shortcut: resolveShortcut(EditorCommandBindings.insertLineBelow, for: "builtin.insert-line-below"),
            category: EditorCommandCategory.edit.rawValue,
            order: 950
        ) {
            state.performLineEdit(.insertLineBelow)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.insert-line-above",
            title: String(localized: "Insert Line Above", table: EditorHostEnvironment.current.localizationTable),
            icon: "text.prepend",
            shortcut: resolveShortcut(EditorCommandBindings.insertLineAbove, for: "builtin.insert-line-above"),
            category: EditorCommandCategory.edit.rawValue,
            order: 960
        ) {
            state.performLineEdit(.insertLineAbove)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.sort-lines-ascending",
            title: String(localized: "Sort Lines Ascending", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.up.arrow.down",
            category: EditorCommandCategory.edit.rawValue,
            order: 970,
            enablement: .whenTrue(.hasSelection)
        ) {
            state.performLineEdit(.sortLinesAscending)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.sort-lines-descending",
            title: String(localized: "Sort Lines Descending", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.down.arrow.up",
            category: EditorCommandCategory.edit.rawValue,
            order: 980,
            enablement: .whenTrue(.hasSelection)
        ) {
            state.performLineEdit(.sortLinesDescending)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.toggle-line-comment",
            title: String(localized: "Toggle Line Comment", table: EditorHostEnvironment.current.localizationTable),
            icon: "number",
            shortcut: resolveShortcut(EditorCommandBindings.toggleLineComment, for: "builtin.toggle-line-comment"),
            category: EditorCommandCategory.edit.rawValue,
            order: 990
        ) {
            state.performLineEdit(.toggleLineComment)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.transpose",
            title: String(localized: "Transpose Characters", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.left.arrow.right",
            shortcut: resolveShortcut(EditorCommandBindings.transpose, for: "builtin.transpose"),
            category: EditorCommandCategory.edit.rawValue,
            order: 1000
        ) {
            state.performLineEdit(.transpose)
        })
    }

    // MARK: - Cursor Motion

    private static func registerCursorMotionCommands(state: EditorState) {
        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.cursor-word-left",
            title: String(localized: "Cursor Word Left", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.left",
            category: EditorCommandCategory.navigation.rawValue,
            order: 550
        ) {
            state.performCursorMotion(.wordLeft)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.cursor-word-right",
            title: String(localized: "Cursor Word Right", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.right",
            category: EditorCommandCategory.navigation.rawValue,
            order: 560
        ) {
            state.performCursorMotion(.wordRight)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.cursor-word-left-select",
            title: String(localized: "Cursor Word Left Select", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.left.square",
            category: EditorCommandCategory.navigation.rawValue,
            order: 570
        ) {
            state.performCursorMotion(.wordLeftSelect)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.cursor-word-right-select",
            title: String(localized: "Cursor Word Right Select", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.right.square",
            category: EditorCommandCategory.navigation.rawValue,
            order: 580
        ) {
            state.performCursorMotion(.wordRightSelect)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.cursor-smart-home",
            title: String(localized: "Cursor Smart Home", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.left.to.line",
            category: EditorCommandCategory.navigation.rawValue,
            order: 590
        ) {
            state.performCursorMotion(.smartHome)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.cursor-smart-home-select",
            title: String(localized: "Cursor Smart Home Select", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.left.to.line.compact",
            category: EditorCommandCategory.navigation.rawValue,
            order: 595
        ) {
            state.performCursorMotion(.smartHomeSelect)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.cursor-line-end",
            title: String(localized: "Cursor Line End", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.right.to.line",
            category: EditorCommandCategory.navigation.rawValue,
            order: 596
        ) {
            state.performCursorMotion(.lineEnd)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.cursor-line-end-select",
            title: String(localized: "Cursor Line End Select", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.right.to.line.compact",
            category: EditorCommandCategory.navigation.rawValue,
            order: 597
        ) {
            state.performCursorMotion(.lineEndSelect)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.cursor-document-start",
            title: String(localized: "Cursor Document Start", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.up.to.line",
            category: EditorCommandCategory.navigation.rawValue,
            order: 598
        ) {
            state.performCursorMotion(.documentStart)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.cursor-document-end",
            title: String(localized: "Cursor Document End", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.down.to.line",
            category: EditorCommandCategory.navigation.rawValue,
            order: 599
        ) {
            state.performCursorMotion(.documentEnd)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.delete-word-left",
            title: String(localized: "Delete Word Left", table: EditorHostEnvironment.current.localizationTable),
            icon: "delete.left",
            category: EditorCommandCategory.edit.rawValue,
            order: 1010
        ) {
            state.performCursorMotion(.deleteWordLeft)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.delete-word-right",
            title: String(localized: "Delete Word Right", table: EditorHostEnvironment.current.localizationTable),
            icon: "delete.right",
            category: EditorCommandCategory.edit.rawValue,
            order: 1020
        ) {
            state.performCursorMotion(.deleteWordRight)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.cursor-paragraph-backward",
            title: String(localized: "Cursor Paragraph Backward", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.up.square",
            category: EditorCommandCategory.navigation.rawValue,
            order: 601
        ) {
            state.performCursorMotion(.paragraphBackward)
        })

        CommandRegistry.shared.register(KernelEditorCommand.command(
            id: "builtin.cursor-paragraph-forward",
            title: String(localized: "Cursor Paragraph Forward", table: EditorHostEnvironment.current.localizationTable),
            icon: "arrow.down.square",
            category: EditorCommandCategory.navigation.rawValue,
            order: 602
        ) {
            state.performCursorMotion(.paragraphForward)
        })
    }
}
