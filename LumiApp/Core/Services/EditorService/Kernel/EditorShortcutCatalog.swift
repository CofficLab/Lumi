import Foundation

@MainActor
enum EditorShortcutCatalog {
    static let commands: [EditorShortcutDefinition] = [
        .init(id: "builtin.undo", title: String(localized: "Undo", table: "LumiEditor"), category: .other, defaultShortcut: EditorCommandBindings.undo.defaultKernelShortcut),
        .init(id: "builtin.redo", title: String(localized: "Redo", table: "LumiEditor"), category: .other, defaultShortcut: EditorCommandBindings.redo.defaultKernelShortcut),
        .init(id: "builtin.format-document", title: String(localized: "Format Document", table: "LumiEditor"), category: .format, defaultShortcut: EditorCommandBindings.formatDocument.defaultKernelShortcut),
        .init(id: "builtin.open-editors-panel", title: String(localized: "Open Editors", table: "LumiEditor"), category: .navigation, defaultShortcut: EditorCommandBindings.openEditors.defaultKernelShortcut),
        .init(id: "builtin.outline-panel", title: String(localized: "Outline", table: "LumiEditor"), category: .navigation, defaultShortcut: nil),
        .init(id: "builtin.find-references", title: String(localized: "Find All References", table: "LumiEditor"), category: .navigation, defaultShortcut: EditorCommandBindings.findReferences.defaultKernelShortcut),
        .init(id: "builtin.quick-fix", title: String(localized: "Quick Fix", table: "LumiEditor"), category: .navigation, defaultShortcut: EditorCommandBindings.quickFix.defaultKernelShortcut),
        .init(id: "builtin.peek-references", title: String(localized: "Peek References", table: "LumiEditor"), category: .navigation, defaultShortcut: nil),
        .init(id: "builtin.rename-symbol", title: String(localized: "Rename Symbol", table: "LumiEditor"), category: .navigation, defaultShortcut: EditorCommandBindings.renameSymbol.defaultKernelShortcut),
        .init(id: "builtin.peek-definition", title: String(localized: "Peek Definition", table: "LumiEditor"), category: .navigation, defaultShortcut: nil),
        .init(id: "builtin.workspace-symbols", title: String(localized: "Go to Symbol in Workspace", table: "LumiEditor"), category: .navigation, defaultShortcut: EditorCommandBindings.workspaceSymbols.defaultKernelShortcut),
        .init(id: "builtin.call-hierarchy", title: String(localized: "Show Call Hierarchy", table: "LumiEditor"), category: .navigation, defaultShortcut: EditorCommandBindings.callHierarchy.defaultKernelShortcut),
        .init(id: "builtin.command-palette", title: String(localized: "Command Palette", table: "LumiEditor"), category: .workbench, defaultShortcut: EditorCommandBindings.commandPalette.defaultKernelShortcut),
        .init(id: "builtin.add-next-occurrence", title: String(localized: "Add Next Occurrence", table: "LumiEditor"), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.select-all-occurrences", title: String(localized: "Select All Occurrences", table: "LumiEditor"), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.remove-last-occurrence-selection", title: String(localized: "Remove Last Occurrence", table: "LumiEditor"), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.clear-additional-cursors", title: String(localized: "Clear Additional Cursors", table: "LumiEditor"), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.find", title: String(localized: "Find", table: "LumiEditor"), category: .find, defaultShortcut: EditorCommandBindings.find.defaultKernelShortcut),
        .init(id: "builtin.search-in-files", title: String(localized: "Search in Files", table: "LumiEditor"), category: .find, defaultShortcut: EditorCommandBindings.searchInFiles.defaultKernelShortcut),
        .init(id: "builtin.find-next", title: String(localized: "Find Next", table: "LumiEditor"), category: .find, defaultShortcut: EditorCommandBindings.findNext.defaultKernelShortcut),
        .init(id: "builtin.find-previous", title: String(localized: "Find Previous", table: "LumiEditor"), category: .find, defaultShortcut: EditorCommandBindings.findPrevious.defaultKernelShortcut),
        .init(id: "builtin.replace-current", title: String(localized: "Replace", table: "LumiEditor"), category: .find, defaultShortcut: nil),
        .init(id: "builtin.replace-all", title: String(localized: "Replace All", table: "LumiEditor"), category: .find, defaultShortcut: nil),
        .init(id: "builtin.open-search-editor", title: String(localized: "Open Search Editor", table: "LumiEditor"), category: .find, defaultShortcut: nil),
        .init(id: "builtin.trigger-completion", title: String(localized: "Trigger Completion", table: "LumiEditor"), category: .lsp, defaultShortcut: nil),
        .init(id: "builtin.trigger-parameter-hints", title: String(localized: "Trigger Parameter Hints", table: "LumiEditor"), category: .lsp, defaultShortcut: nil),
        .init(id: "builtin.save", title: String(localized: "Save", table: "LumiEditor"), category: .save, defaultShortcut: nil),
        .init(id: "builtin.delete-line", title: String(localized: "Delete Line", table: "LumiEditor"), category: .edit, defaultShortcut: EditorCommandBindings.deleteLine.defaultKernelShortcut),
        .init(id: "builtin.copy-line-down", title: String(localized: "Copy Line Down", table: "LumiEditor"), category: .edit, defaultShortcut: EditorCommandBindings.copyLineDown.defaultKernelShortcut),
        .init(id: "builtin.copy-line-up", title: String(localized: "Copy Line Up", table: "LumiEditor"), category: .edit, defaultShortcut: EditorCommandBindings.copyLineUp.defaultKernelShortcut),
        .init(id: "builtin.move-line-down", title: String(localized: "Move Line Down", table: "LumiEditor"), category: .edit, defaultShortcut: EditorCommandBindings.moveLineDown.defaultKernelShortcut),
        .init(id: "builtin.move-line-up", title: String(localized: "Move Line Up", table: "LumiEditor"), category: .edit, defaultShortcut: EditorCommandBindings.moveLineUp.defaultKernelShortcut),
        .init(id: "builtin.insert-line-below", title: String(localized: "Insert Line Below", table: "LumiEditor"), category: .edit, defaultShortcut: EditorCommandBindings.insertLineBelow.defaultKernelShortcut),
        .init(id: "builtin.insert-line-above", title: String(localized: "Insert Line Above", table: "LumiEditor"), category: .edit, defaultShortcut: EditorCommandBindings.insertLineAbove.defaultKernelShortcut),
        .init(id: "builtin.sort-lines-ascending", title: String(localized: "Sort Lines Ascending", table: "LumiEditor"), category: .edit, defaultShortcut: nil),
        .init(id: "builtin.sort-lines-descending", title: String(localized: "Sort Lines Descending", table: "LumiEditor"), category: .edit, defaultShortcut: nil),
        .init(id: "builtin.toggle-line-comment", title: String(localized: "Toggle Line Comment", table: "LumiEditor"), category: .edit, defaultShortcut: EditorCommandBindings.toggleLineComment.defaultKernelShortcut),
        .init(id: "builtin.transpose", title: String(localized: "Transpose Characters", table: "LumiEditor"), category: .edit, defaultShortcut: EditorCommandBindings.transpose.defaultKernelShortcut),
    ]

    static func command(id: String) -> EditorShortcutDefinition? {
        commands.first(where: { $0.id == id })
    }

    static func filteredCommands(query: String, category: EditorCommandCategory?) -> [EditorShortcutDefinition] {
        EditorShortcutCatalogPolicy.filteredCommands(
            commands,
            query: query,
            category: category,
            customBindings: EditorKeybindingStore.shared.customBindings
        )
    }

    static func effectiveShortcut(for command: EditorShortcutDefinition, customBindings: [String: EditorKeybindingEntry]) -> EditorCommandShortcut? {
        EditorShortcutCatalogPolicy.effectiveShortcut(for: command, customBindings: customBindings)
    }

    static func conflicts(
        for commandID: String,
        candidate: EditorCommandShortcut,
        customBindings: [String: EditorKeybindingEntry]
    ) -> [EditorShortcutDefinition] {
        EditorShortcutCatalogPolicy.conflicts(
            in: commands,
            for: commandID,
            candidate: candidate,
            customBindings: customBindings
        )
    }
}
