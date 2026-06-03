import Foundation

@MainActor
public enum EditorShortcutCatalog {
    public static let commands: [EditorShortcutDefinition] = [
        .init(id: "builtin.undo", title: String(localized: "Undo", bundle: .module), category: .other, defaultShortcut: EditorCommandBindings.undo.defaultKernelShortcut),
        .init(id: "builtin.redo", title: String(localized: "Redo", bundle: .module), category: .other, defaultShortcut: EditorCommandBindings.redo.defaultKernelShortcut),
        .init(id: "builtin.format-document", title: String(localized: "Format Document", bundle: .module), category: .format, defaultShortcut: EditorCommandBindings.formatDocument.defaultKernelShortcut),
        .init(id: "builtin.open-editors-panel", title: String(localized: "Open Editors", bundle: .module), category: .navigation, defaultShortcut: EditorCommandBindings.openEditors.defaultKernelShortcut),
        .init(id: "builtin.outline-panel", title: String(localized: "Outline", bundle: .module), category: .navigation, defaultShortcut: nil),
        .init(id: "builtin.find-references", title: String(localized: "Find All References", bundle: .module), category: .navigation, defaultShortcut: EditorCommandBindings.findReferences.defaultKernelShortcut),
        .init(id: "builtin.quick-fix", title: String(localized: "Quick Fix", bundle: .module), category: .navigation, defaultShortcut: EditorCommandBindings.quickFix.defaultKernelShortcut),
        .init(id: "builtin.peek-references", title: String(localized: "Peek References", bundle: .module), category: .navigation, defaultShortcut: nil),
        .init(id: "builtin.rename-symbol", title: String(localized: "Rename Symbol", bundle: .module), category: .navigation, defaultShortcut: EditorCommandBindings.renameSymbol.defaultKernelShortcut),
        .init(id: "builtin.peek-definition", title: String(localized: "Peek Definition", bundle: .module), category: .navigation, defaultShortcut: nil),
        .init(id: "builtin.workspace-symbols", title: String(localized: "Go to Symbol in Workspace", bundle: .module), category: .navigation, defaultShortcut: EditorCommandBindings.workspaceSymbols.defaultKernelShortcut),
        .init(id: "builtin.call-hierarchy", title: String(localized: "Show Call Hierarchy", bundle: .module), category: .navigation, defaultShortcut: EditorCommandBindings.callHierarchy.defaultKernelShortcut),
        .init(id: "builtin.command-palette", title: String(localized: "Command Palette", bundle: .module), category: .workbench, defaultShortcut: EditorCommandBindings.commandPalette.defaultKernelShortcut),
        .init(id: "builtin.add-next-occurrence", title: String(localized: "Add Next Occurrence", bundle: .module), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.select-all-occurrences", title: String(localized: "Select All Occurrences", bundle: .module), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.remove-last-occurrence-selection", title: String(localized: "Remove Last Occurrence", bundle: .module), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.clear-additional-cursors", title: String(localized: "Clear Additional Cursors", bundle: .module), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.find", title: String(localized: "Find", bundle: .module), category: .find, defaultShortcut: EditorCommandBindings.find.defaultKernelShortcut),
        .init(id: "builtin.search-in-files", title: String(localized: "Search in Files", bundle: .module), category: .find, defaultShortcut: EditorCommandBindings.searchInFiles.defaultKernelShortcut),
        .init(id: "builtin.find-next", title: String(localized: "Find Next", bundle: .module), category: .find, defaultShortcut: EditorCommandBindings.findNext.defaultKernelShortcut),
        .init(id: "builtin.find-previous", title: String(localized: "Find Previous", bundle: .module), category: .find, defaultShortcut: EditorCommandBindings.findPrevious.defaultKernelShortcut),
        .init(id: "builtin.replace-current", title: String(localized: "Replace", bundle: .module), category: .find, defaultShortcut: nil),
        .init(id: "builtin.replace-all", title: String(localized: "Replace All", bundle: .module), category: .find, defaultShortcut: nil),
        .init(id: "builtin.open-search-editor", title: String(localized: "Open Search Editor", bundle: .module), category: .find, defaultShortcut: nil),
        .init(id: "builtin.trigger-completion", title: String(localized: "Trigger Completion", bundle: .module), category: .lsp, defaultShortcut: nil),
        .init(id: "builtin.trigger-parameter-hints", title: String(localized: "Trigger Parameter Hints", bundle: .module), category: .lsp, defaultShortcut: nil),
        .init(id: "builtin.save", title: String(localized: "Save", bundle: .module), category: .save, defaultShortcut: EditorCommandBindings.save.defaultKernelShortcut),
        .init(id: "builtin.delete-line", title: String(localized: "Delete Line", bundle: .module), category: .edit, defaultShortcut: EditorCommandBindings.deleteLine.defaultKernelShortcut),
        .init(id: "builtin.copy-line-down", title: String(localized: "Copy Line Down", bundle: .module), category: .edit, defaultShortcut: EditorCommandBindings.copyLineDown.defaultKernelShortcut),
        .init(id: "builtin.copy-line-up", title: String(localized: "Copy Line Up", bundle: .module), category: .edit, defaultShortcut: EditorCommandBindings.copyLineUp.defaultKernelShortcut),
        .init(id: "builtin.move-line-down", title: String(localized: "Move Line Down", bundle: .module), category: .edit, defaultShortcut: EditorCommandBindings.moveLineDown.defaultKernelShortcut),
        .init(id: "builtin.move-line-up", title: String(localized: "Move Line Up", bundle: .module), category: .edit, defaultShortcut: EditorCommandBindings.moveLineUp.defaultKernelShortcut),
        .init(id: "builtin.insert-line-below", title: String(localized: "Insert Line Below", bundle: .module), category: .edit, defaultShortcut: EditorCommandBindings.insertLineBelow.defaultKernelShortcut),
        .init(id: "builtin.insert-line-above", title: String(localized: "Insert Line Above", bundle: .module), category: .edit, defaultShortcut: EditorCommandBindings.insertLineAbove.defaultKernelShortcut),
        .init(id: "builtin.sort-lines-ascending", title: String(localized: "Sort Lines Ascending", bundle: .module), category: .edit, defaultShortcut: nil),
        .init(id: "builtin.sort-lines-descending", title: String(localized: "Sort Lines Descending", bundle: .module), category: .edit, defaultShortcut: nil),
        .init(id: "builtin.toggle-line-comment", title: String(localized: "Toggle Line Comment", bundle: .module), category: .edit, defaultShortcut: EditorCommandBindings.toggleLineComment.defaultKernelShortcut),
        .init(id: "builtin.transpose", title: String(localized: "Transpose Characters", bundle: .module), category: .edit, defaultShortcut: EditorCommandBindings.transpose.defaultKernelShortcut),
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
