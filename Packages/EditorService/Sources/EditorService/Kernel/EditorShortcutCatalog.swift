import Foundation

@MainActor
public enum EditorShortcutCatalog {
    public static let commands: [EditorShortcutDefinition] = [
        .init(id: "builtin.undo", title: String(localized: "Undo", table: EditorHostEnvironment.current.localizationTable), category: .other, defaultShortcut: EditorCommandBindings.undo.defaultKernelShortcut),
        .init(id: "builtin.redo", title: String(localized: "Redo", table: EditorHostEnvironment.current.localizationTable), category: .other, defaultShortcut: EditorCommandBindings.redo.defaultKernelShortcut),
        .init(id: "builtin.format-document", title: String(localized: "Format Document", table: EditorHostEnvironment.current.localizationTable), category: .format, defaultShortcut: EditorCommandBindings.formatDocument.defaultKernelShortcut),
        .init(id: "builtin.open-editors-panel", title: String(localized: "Open Editors", table: EditorHostEnvironment.current.localizationTable), category: .navigation, defaultShortcut: EditorCommandBindings.openEditors.defaultKernelShortcut),
        .init(id: "builtin.outline-panel", title: String(localized: "Outline", table: EditorHostEnvironment.current.localizationTable), category: .navigation, defaultShortcut: nil),
        .init(id: "builtin.find-references", title: String(localized: "Find All References", table: EditorHostEnvironment.current.localizationTable), category: .navigation, defaultShortcut: EditorCommandBindings.findReferences.defaultKernelShortcut),
        .init(id: "builtin.quick-fix", title: String(localized: "Quick Fix", table: EditorHostEnvironment.current.localizationTable), category: .navigation, defaultShortcut: EditorCommandBindings.quickFix.defaultKernelShortcut),
        .init(id: "builtin.peek-references", title: String(localized: "Peek References", table: EditorHostEnvironment.current.localizationTable), category: .navigation, defaultShortcut: nil),
        .init(id: "builtin.rename-symbol", title: String(localized: "Rename Symbol", table: EditorHostEnvironment.current.localizationTable), category: .navigation, defaultShortcut: EditorCommandBindings.renameSymbol.defaultKernelShortcut),
        .init(id: "builtin.peek-definition", title: String(localized: "Peek Definition", table: EditorHostEnvironment.current.localizationTable), category: .navigation, defaultShortcut: nil),
        .init(id: "builtin.workspace-symbols", title: String(localized: "Go to Symbol in Workspace", table: EditorHostEnvironment.current.localizationTable), category: .navigation, defaultShortcut: EditorCommandBindings.workspaceSymbols.defaultKernelShortcut),
        .init(id: "builtin.call-hierarchy", title: String(localized: "Show Call Hierarchy", table: EditorHostEnvironment.current.localizationTable), category: .navigation, defaultShortcut: EditorCommandBindings.callHierarchy.defaultKernelShortcut),
        .init(id: "builtin.command-palette", title: String(localized: "Command Palette", table: EditorHostEnvironment.current.localizationTable), category: .workbench, defaultShortcut: EditorCommandBindings.commandPalette.defaultKernelShortcut),
        .init(id: "builtin.add-next-occurrence", title: String(localized: "Add Next Occurrence", table: EditorHostEnvironment.current.localizationTable), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.select-all-occurrences", title: String(localized: "Select All Occurrences", table: EditorHostEnvironment.current.localizationTable), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.remove-last-occurrence-selection", title: String(localized: "Remove Last Occurrence", table: EditorHostEnvironment.current.localizationTable), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.clear-additional-cursors", title: String(localized: "Clear Additional Cursors", table: EditorHostEnvironment.current.localizationTable), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.find", title: String(localized: "Find", table: EditorHostEnvironment.current.localizationTable), category: .find, defaultShortcut: EditorCommandBindings.find.defaultKernelShortcut),
        .init(id: "builtin.search-in-files", title: String(localized: "Search in Files", table: EditorHostEnvironment.current.localizationTable), category: .find, defaultShortcut: EditorCommandBindings.searchInFiles.defaultKernelShortcut),
        .init(id: "builtin.find-next", title: String(localized: "Find Next", table: EditorHostEnvironment.current.localizationTable), category: .find, defaultShortcut: EditorCommandBindings.findNext.defaultKernelShortcut),
        .init(id: "builtin.find-previous", title: String(localized: "Find Previous", table: EditorHostEnvironment.current.localizationTable), category: .find, defaultShortcut: EditorCommandBindings.findPrevious.defaultKernelShortcut),
        .init(id: "builtin.replace-current", title: String(localized: "Replace", table: EditorHostEnvironment.current.localizationTable), category: .find, defaultShortcut: nil),
        .init(id: "builtin.replace-all", title: String(localized: "Replace All", table: EditorHostEnvironment.current.localizationTable), category: .find, defaultShortcut: nil),
        .init(id: "builtin.open-search-editor", title: String(localized: "Open Search Editor", table: EditorHostEnvironment.current.localizationTable), category: .find, defaultShortcut: nil),
        .init(id: "builtin.trigger-completion", title: String(localized: "Trigger Completion", table: EditorHostEnvironment.current.localizationTable), category: .lsp, defaultShortcut: nil),
        .init(id: "builtin.trigger-parameter-hints", title: String(localized: "Trigger Parameter Hints", table: EditorHostEnvironment.current.localizationTable), category: .lsp, defaultShortcut: nil),
        .init(id: "builtin.save", title: String(localized: "Save", table: EditorHostEnvironment.current.localizationTable), category: .save, defaultShortcut: EditorCommandBindings.save.defaultKernelShortcut),
        .init(id: "builtin.delete-line", title: String(localized: "Delete Line", table: EditorHostEnvironment.current.localizationTable), category: .edit, defaultShortcut: EditorCommandBindings.deleteLine.defaultKernelShortcut),
        .init(id: "builtin.copy-line-down", title: String(localized: "Copy Line Down", table: EditorHostEnvironment.current.localizationTable), category: .edit, defaultShortcut: EditorCommandBindings.copyLineDown.defaultKernelShortcut),
        .init(id: "builtin.copy-line-up", title: String(localized: "Copy Line Up", table: EditorHostEnvironment.current.localizationTable), category: .edit, defaultShortcut: EditorCommandBindings.copyLineUp.defaultKernelShortcut),
        .init(id: "builtin.move-line-down", title: String(localized: "Move Line Down", table: EditorHostEnvironment.current.localizationTable), category: .edit, defaultShortcut: EditorCommandBindings.moveLineDown.defaultKernelShortcut),
        .init(id: "builtin.move-line-up", title: String(localized: "Move Line Up", table: EditorHostEnvironment.current.localizationTable), category: .edit, defaultShortcut: EditorCommandBindings.moveLineUp.defaultKernelShortcut),
        .init(id: "builtin.insert-line-below", title: String(localized: "Insert Line Below", table: EditorHostEnvironment.current.localizationTable), category: .edit, defaultShortcut: EditorCommandBindings.insertLineBelow.defaultKernelShortcut),
        .init(id: "builtin.insert-line-above", title: String(localized: "Insert Line Above", table: EditorHostEnvironment.current.localizationTable), category: .edit, defaultShortcut: EditorCommandBindings.insertLineAbove.defaultKernelShortcut),
        .init(id: "builtin.sort-lines-ascending", title: String(localized: "Sort Lines Ascending", table: EditorHostEnvironment.current.localizationTable), category: .edit, defaultShortcut: nil),
        .init(id: "builtin.sort-lines-descending", title: String(localized: "Sort Lines Descending", table: EditorHostEnvironment.current.localizationTable), category: .edit, defaultShortcut: nil),
        .init(id: "builtin.toggle-line-comment", title: String(localized: "Toggle Line Comment", table: EditorHostEnvironment.current.localizationTable), category: .edit, defaultShortcut: EditorCommandBindings.toggleLineComment.defaultKernelShortcut),
        .init(id: "builtin.transpose", title: String(localized: "Transpose Characters", table: EditorHostEnvironment.current.localizationTable), category: .edit, defaultShortcut: EditorCommandBindings.transpose.defaultKernelShortcut),
    ]

    public static func command(id: String) -> EditorShortcutDefinition? {
        commands.first(where: { $0.id == id })
    }

    public static func filteredCommands(query: String, category: EditorCommandCategory?) -> [EditorShortcutDefinition] {
        EditorShortcutCatalogPolicy.filteredCommands(
            commands,
            query: query,
            category: category,
            customBindings: EditorKeybindingStore.shared.customBindings
        )
    }

    public static func effectiveShortcut(for command: EditorShortcutDefinition, customBindings: [String: EditorKeybindingEntry]) -> EditorCommandShortcut? {
        EditorShortcutCatalogPolicy.effectiveShortcut(for: command, customBindings: customBindings)
    }

    public static func conflicts(
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
