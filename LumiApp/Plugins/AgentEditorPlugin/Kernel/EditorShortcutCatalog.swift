import Foundation

struct EditorShortcutDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let category: EditorCommandCategory
    let defaultShortcut: EditorCommandShortcut?

    var searchTokens: [String] {
        var tokens = [id, title, category.rawValue, category.displayTitle]
        if let defaultShortcut {
            tokens.append(defaultShortcut.displayText)
        }
        return tokens
    }
}

@MainActor
enum EditorShortcutCatalog {
    static let commands: [EditorShortcutDefinition] = [
        .init(id: "builtin.undo", title: String(localized: "Undo", table: "LumiEditor"), category: .other, defaultShortcut: EditorCommandBindings.undo.defaultKernelShortcut),
        .init(id: "builtin.redo", title: String(localized: "Redo", table: "LumiEditor"), category: .other, defaultShortcut: EditorCommandBindings.redo.defaultKernelShortcut),
        .init(id: "builtin.format-document", title: String(localized: "Format Document", table: "LumiEditor"), category: .format, defaultShortcut: EditorCommandBindings.formatDocument.defaultKernelShortcut),
        .init(id: "builtin.open-editors-panel", title: String(localized: "Open Editors", table: "LumiEditor"), category: .navigation, defaultShortcut: EditorCommandBindings.openEditors.defaultKernelShortcut),
        .init(id: "builtin.find-references", title: String(localized: "Find All References", table: "LumiEditor"), category: .navigation, defaultShortcut: EditorCommandBindings.findReferences.defaultKernelShortcut),
        .init(id: "builtin.peek-references", title: String(localized: "Peek References", table: "LumiEditor"), category: .navigation, defaultShortcut: nil),
        .init(id: "builtin.rename-symbol", title: String(localized: "Rename Symbol", table: "LumiEditor"), category: .navigation, defaultShortcut: EditorCommandBindings.renameSymbol.defaultKernelShortcut),
        .init(id: "builtin.peek-definition", title: String(localized: "Peek Definition", table: "LumiEditor"), category: .navigation, defaultShortcut: nil),
        .init(id: "builtin.workspace-symbols", title: String(localized: "Go to Symbol in Workspace", table: "LumiEditor"), category: .navigation, defaultShortcut: EditorCommandBindings.workspaceSymbols.defaultKernelShortcut),
        .init(id: "builtin.call-hierarchy", title: String(localized: "Show Call Hierarchy", table: "LumiEditor"), category: .navigation, defaultShortcut: EditorCommandBindings.callHierarchy.defaultKernelShortcut),
        .init(id: "builtin.command-palette", title: String(localized: "Command Palette", table: "LumiEditor"), category: .workbench, defaultShortcut: EditorCommandBindings.commandPalette.defaultKernelShortcut),
        .init(id: "builtin.split-right", title: String(localized: "Split Editor Right", table: "LumiEditor"), category: .workbench, defaultShortcut: EditorCommandBindings.splitRight.defaultKernelShortcut),
        .init(id: "builtin.split-down", title: String(localized: "Split Editor Down", table: "LumiEditor"), category: .workbench, defaultShortcut: EditorCommandBindings.splitDown.defaultKernelShortcut),
        .init(id: "builtin.close-split", title: String(localized: "Close Split Editor", table: "LumiEditor"), category: .workbench, defaultShortcut: EditorCommandBindings.closeSplit.defaultKernelShortcut),
        .init(id: "builtin.focus-next-group", title: String(localized: "Focus Next Editor Group", table: "LumiEditor"), category: .workbench, defaultShortcut: EditorCommandBindings.focusNextGroup.defaultKernelShortcut),
        .init(id: "builtin.focus-previous-group", title: String(localized: "Focus Previous Editor Group", table: "LumiEditor"), category: .workbench, defaultShortcut: EditorCommandBindings.focusPreviousGroup.defaultKernelShortcut),
        .init(id: "builtin.move-to-next-group", title: String(localized: "Move Editor to Next Group", table: "LumiEditor"), category: .workbench, defaultShortcut: EditorCommandBindings.moveToNextGroup.defaultKernelShortcut),
        .init(id: "builtin.move-to-previous-group", title: String(localized: "Move Editor to Previous Group", table: "LumiEditor"), category: .workbench, defaultShortcut: EditorCommandBindings.moveToPreviousGroup.defaultKernelShortcut),
        .init(id: "builtin.add-next-occurrence", title: String(localized: "Add Next Occurrence", table: "LumiEditor"), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.select-all-occurrences", title: String(localized: "Select All Occurrences", table: "LumiEditor"), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.remove-last-occurrence-selection", title: String(localized: "Remove Last Occurrence", table: "LumiEditor"), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.clear-additional-cursors", title: String(localized: "Clear Additional Cursors", table: "LumiEditor"), category: .multiCursor, defaultShortcut: nil),
        .init(id: "builtin.find", title: String(localized: "Find", table: "LumiEditor"), category: .find, defaultShortcut: EditorCommandBindings.find.defaultKernelShortcut),
        .init(id: "builtin.find-next", title: String(localized: "Find Next", table: "LumiEditor"), category: .find, defaultShortcut: EditorCommandBindings.findNext.defaultKernelShortcut),
        .init(id: "builtin.find-previous", title: String(localized: "Find Previous", table: "LumiEditor"), category: .find, defaultShortcut: EditorCommandBindings.findPrevious.defaultKernelShortcut),
        .init(id: "builtin.replace-current", title: String(localized: "Replace", table: "LumiEditor"), category: .find, defaultShortcut: nil),
        .init(id: "builtin.replace-all", title: String(localized: "Replace All", table: "LumiEditor"), category: .find, defaultShortcut: nil),
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
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return commands.filter { command in
            let categoryMatches = category.map { command.category == $0 } ?? true
            guard categoryMatches else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            let effectiveShortcutText = effectiveShortcut(for: command, customBindings: EditorKeybindingStore.shared.customBindings)?.displayText ?? ""
            return (command.searchTokens + [effectiveShortcutText]).contains {
                $0.localizedCaseInsensitiveContains(normalizedQuery)
            }
        }
        .sorted {
            let lhsCategory = EditorCommandCategory.orderIndex(for: $0.category.rawValue)
            let rhsCategory = EditorCommandCategory.orderIndex(for: $1.category.rawValue)
            if lhsCategory != rhsCategory {
                return lhsCategory < rhsCategory
            }
            return $0.title.localizedLowercase < $1.title.localizedLowercase
        }
    }

    static func effectiveShortcut(for command: EditorShortcutDefinition, customBindings: [String: EditorKeybindingEntry]) -> EditorCommandShortcut? {
        if let custom = customBindings[command.id] {
            return custom.shortcut
        }
        return command.defaultShortcut
    }

    static func conflicts(
        for commandID: String,
        candidate: EditorCommandShortcut,
        customBindings: [String: EditorKeybindingEntry]
    ) -> [EditorShortcutDefinition] {
        let normalizedCandidate = candidate.normalizedForMatching
        return commands.filter { command in
            guard command.id != commandID else { return false }
            guard let shortcut = effectiveShortcut(for: command, customBindings: customBindings) else { return false }
            return shortcut.normalizedForMatching == normalizedCandidate
        }
    }
}

private extension EditorCommandShortcut.Modifier {
    var sortOrder: Int {
        switch self {
        case .command: return 0
        case .shift: return 1
        case .option: return 2
        case .control: return 3
        }
    }
}

private extension EditorCommandShortcut {
    var normalizedForMatching: String {
        modifiers.sorted { $0.sortOrder < $1.sortOrder }.map(\.rawValue).joined(separator: "+")
            + "|"
            + key.lowercased()
    }
}
