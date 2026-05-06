import Foundation

public struct CommandKey: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct CommandContext {
    public private(set) var values: [String: AnyHashable] = [:]

    public init(values: [String: AnyHashable] = [:]) {
        self.values = values
    }

    public subscript(_ key: CommandKey) -> AnyHashable? {
        get { values[key.rawValue] }
        set { values[key.rawValue] = newValue }
    }

    public var hasSelection: Bool {
        get { values[CommandKey.hasSelection.rawValue] as? Bool ?? false }
        set { values[CommandKey.hasSelection.rawValue] = newValue }
    }

    public var languageId: String? {
        get { values[CommandKey.languageId.rawValue] as? String }
        set { values[CommandKey.languageId.rawValue] = newValue }
    }

    public var line: Int? {
        get { values[CommandKey.line.rawValue] as? Int }
        set { values[CommandKey.line.rawValue] = newValue }
    }

    public var character: Int? {
        get { values[CommandKey.character.rawValue] as? Int }
        set { values[CommandKey.character.rawValue] = newValue }
    }

    public var isEditorActive: Bool {
        get { values[CommandKey.isEditorActive.rawValue] as? Bool ?? false }
        set { values[CommandKey.isEditorActive.rawValue] = newValue }
    }

    public var isMultiCursor: Bool {
        get { values[CommandKey.isMultiCursor.rawValue] as? Bool ?? false }
        set { values[CommandKey.isMultiCursor.rawValue] = newValue }
    }
}

public extension CommandKey {
    static let hasSelection = CommandKey("hasSelection")
    static let languageId = CommandKey("languageId")
    static let line = CommandKey("line")
    static let character = CommandKey("character")
    static let isEditorActive = CommandKey("isEditorActive")
    static let isMultiCursor = CommandKey("isMultiCursor")
}

public enum CommandEnablement {
    case always
    case whenTrue(CommandKey)
    case whenPresent(CommandKey)
    case custom((CommandContext) -> Bool)

    public func evaluate(in context: CommandContext) -> Bool {
        switch self {
        case .always:
            return true
        case .whenTrue(let key):
            return (context.values[key.rawValue] as? Bool) == true
        case .whenPresent(let key):
            return context.values[key.rawValue] != nil
        case .custom(let predicate):
            return predicate(context)
        }
    }
}

public struct KernelEditorCommand: Identifiable {
    public let id: String
    public let title: String
    public let icon: String?
    public let shortcut: EditorCommandShortcut?
    public let category: String?
    public let order: Int
    public let enablement: CommandEnablement
    public let handler: () -> Void

    public init(
        id: String,
        title: String,
        icon: String? = nil,
        shortcut: EditorCommandShortcut? = nil,
        category: String? = nil,
        order: Int = 0,
        enablement: CommandEnablement = .always,
        handler: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.shortcut = shortcut
        self.category = category
        self.order = order
        self.enablement = enablement
        self.handler = handler
    }

    public func isEnabled(in context: CommandContext) -> Bool {
        enablement.evaluate(in: context)
    }

    public static func command(
        id: String,
        title: String,
        icon: String? = nil,
        shortcut: EditorCommandShortcut? = nil,
        category: String? = nil,
        order: Int = 0,
        enablement: CommandEnablement = .always,
        handler: @escaping () -> Void
    ) -> KernelEditorCommand {
        KernelEditorCommand(
            id: id,
            title: title,
            icon: icon,
            shortcut: shortcut,
            category: category,
            order: order,
            enablement: enablement,
            handler: handler
        )
    }

    public static func selectionCommand(
        id: String,
        title: String,
        icon: String? = nil,
        shortcut: EditorCommandShortcut? = nil,
        category: String? = nil,
        order: Int = 0,
        handler: @escaping () -> Void
    ) -> KernelEditorCommand {
        KernelEditorCommand(
            id: id,
            title: title,
            icon: icon,
            shortcut: shortcut,
            category: category,
            order: order,
            enablement: .whenTrue(.hasSelection),
            handler: handler
        )
    }
}

@MainActor
public final class CommandRegistry {
    public static let shared = CommandRegistry()

    private var commands: [String: KernelEditorCommand] = [:]

    public init() {}

    public func register(_ command: KernelEditorCommand) {
        commands[command.id] = command
    }

    public func register(_ commands: [KernelEditorCommand]) {
        for command in commands {
            register(command)
        }
    }

    public func command(id: String) -> KernelEditorCommand? {
        commands[id]
    }

    public func allCommands() -> [KernelEditorCommand] {
        Array(commands.values).sorted {
            ($0.order, $0.title.localizedLowercase, $0.id) < ($1.order, $1.title.localizedLowercase, $1.id)
        }
    }

    public func availableCommands(in context: CommandContext) -> [KernelEditorCommand] {
        commands.values.filter { $0.isEnabled(in: context) }
            .sorted {
                ($0.order, $0.title.localizedLowercase, $0.id) < ($1.order, $1.title.localizedLowercase, $1.id)
            }
    }

    @discardableResult
    public func execute(id: String, context: CommandContext) -> Bool {
        guard let command = commands[id], command.isEnabled(in: context) else {
            return false
        }
        command.handler()
        return true
    }

    public func unregister(id: String) {
        commands.removeValue(forKey: id)
    }

    public func clear() {
        commands.removeAll()
    }
}
