import Foundation

public struct EditorShortcutDefinition: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let category: EditorCommandCategory
    public let defaultShortcut: EditorCommandShortcut?

    public init(
        id: String,
        title: String,
        category: EditorCommandCategory,
        defaultShortcut: EditorCommandShortcut?
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.defaultShortcut = defaultShortcut
    }

    public var searchTokens: [String] {
        var tokens = [id, title, category.rawValue, category.displayTitle]
        if let defaultShortcut {
            tokens.append(defaultShortcut.displayText)
        }
        return tokens
    }
}

public struct EditorKeybindingEntry: Equatable, Codable, Sendable {
    public let commandID: String
    public let key: String
    public let modifiers: [EditorCommandShortcut.Modifier]

    public var shortcut: EditorCommandShortcut {
        EditorCommandShortcut(key: key, modifiers: modifiers)
    }

    public var dictionaryValue: [String: Any] {
        [
            "commandID": commandID,
            "key": key,
            "modifiers": modifiers.map(\.rawValue),
        ]
    }

    public init?(dictionary: [String: Any]) {
        guard let commandID = dictionary["commandID"] as? String,
              let key = dictionary["key"] as? String,
              let rawModifiers = dictionary["modifiers"] as? [String] else {
            return nil
        }
        self.commandID = commandID
        self.key = key
        self.modifiers = rawModifiers.compactMap { EditorCommandShortcut.Modifier(rawValue: $0) }
    }

    public init(commandID: String, key: String, modifiers: [EditorCommandShortcut.Modifier]) {
        self.commandID = commandID
        self.key = key
        self.modifiers = modifiers
    }
}

@MainActor
public enum EditorShortcutCatalogPolicy {
    public static func effectiveShortcut(
        for command: EditorShortcutDefinition,
        customBindings: [String: EditorKeybindingEntry]
    ) -> EditorCommandShortcut? {
        if let custom = customBindings[command.id] {
            return custom.shortcut
        }
        return command.defaultShortcut
    }

    public static func filteredCommands(
        _ commands: [EditorShortcutDefinition],
        query: String,
        category: EditorCommandCategory?,
        customBindings: [String: EditorKeybindingEntry]
    ) -> [EditorShortcutDefinition] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return commands.filter { command in
            let categoryMatches = category.map { command.category == $0 } ?? true
            guard categoryMatches else { return false }
            guard !normalizedQuery.isEmpty else { return true }
            let effectiveShortcutText = effectiveShortcut(for: command, customBindings: customBindings)?.displayText ?? ""
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

    public static func conflicts(
        in commands: [EditorShortcutDefinition],
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
