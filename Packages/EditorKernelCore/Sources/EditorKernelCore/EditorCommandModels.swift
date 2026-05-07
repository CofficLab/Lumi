import Foundation

public struct EditorCommandShortcut: Equatable, Sendable {
    public enum Modifier: String, CaseIterable, Codable, Sendable {
        case command
        case shift
        case option
        case control

        public var symbol: String {
            switch self {
            case .command: return "⌘"
            case .shift: return "⇧"
            case .option: return "⌥"
            case .control: return "⌃"
            }
        }
    }

    public let key: String
    public let modifiers: [Modifier]

    public var displayText: String {
        modifiers.map(\.symbol).joined() + key.uppercased()
    }

    public init(key: String, modifiers: [Modifier]) {
        self.key = key
        self.modifiers = modifiers
    }
}

@MainActor
public struct EditorCommandContext {
    public let languageId: String
    public let hasSelection: Bool
    public let line: Int
    public let character: Int

    public init(
        languageId: String,
        hasSelection: Bool,
        line: Int,
        character: Int
    ) {
        self.languageId = languageId
        self.hasSelection = hasSelection
        self.line = line
        self.character = character
    }
}

@MainActor
public struct EditorCommandSuggestion: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let category: String?
    public let shortcut: EditorCommandShortcut?
    public let order: Int
    public let isEnabled: Bool
    public let action: () -> Void

    public init(
        id: String,
        title: String,
        systemImage: String,
        category: String? = nil,
        shortcut: EditorCommandShortcut? = nil,
        order: Int,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.category = category
        self.shortcut = shortcut
        self.order = order
        self.isEnabled = isEnabled
        self.action = action
    }
}

public struct EditorCommandSection: Identifiable {
    public let category: EditorCommandCategory
    public let commands: [EditorCommandSuggestion]

    public var id: String { category.rawValue }
    public var title: String { category.displayTitle }

    public init(category: EditorCommandCategory, commands: [EditorCommandSuggestion]) {
        self.category = category
        self.commands = commands
    }
}
