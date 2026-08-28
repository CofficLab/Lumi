import Foundation

public enum CommandMenuPlacement: String, Sendable {
    case appMenu
    case toolbar
    case topLevelMenu
}

@MainActor
public enum CommandProvidingEvent {
    case groupsChanged
}

@MainActor
public protocol CommandProvidingObserverHandle: AnyObject {
    func cancel()
}

public enum CommandState: Sendable {
    case off
    case on
}

public struct CommandModifiers: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = Self(rawValue: 1 << 0)
    public static let shift = Self(rawValue: 1 << 1)
    public static let option = Self(rawValue: 1 << 2)
    public static let control = Self(rawValue: 1 << 3)
}

public struct CommandItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let shortcut: Character?
    public let modifiers: CommandModifiers
    public let action: @MainActor @Sendable () -> Void

    private let stateProvider: @MainActor @Sendable () -> CommandState

    public init(
        id: String,
        title: String,
        shortcut: Character? = nil,
        modifiers: CommandModifiers = [],
        state: CommandState = .off,
        action: @escaping @MainActor @Sendable () -> Void
    ) {
        self.id = id
        self.title = title
        self.shortcut = shortcut
        self.modifiers = modifiers
        self.stateProvider = { state }
        self.action = action
    }

    public init(
        id: String,
        title: String,
        shortcut: Character? = nil,
        modifiers: CommandModifiers = [],
        stateProvider: @escaping @MainActor @Sendable () -> CommandState,
        action: @escaping @MainActor @Sendable () -> Void
    ) {
        self.id = id
        self.title = title
        self.shortcut = shortcut
        self.modifiers = modifiers
        self.stateProvider = stateProvider
        self.action = action
    }

    @MainActor
    public var state: CommandState {
        stateProvider()
    }
}

public struct CommandMenuGroup: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let items: [CommandItem]
    public let placement: CommandMenuPlacement

    public init(id: String, name: String, items: [CommandItem], placement: CommandMenuPlacement) {
        self.id = id
        self.name = name
        self.items = items
        self.placement = placement
    }
}

@MainActor
public protocol CommandProviding: AnyObject {
    var allCommandGroups: [CommandMenuGroup] { get }
    func registerCommandGroup(_ group: CommandMenuGroup)
    func unregisterCommandGroup(id: String)

    @discardableResult
    func addObserver(_ callback: @escaping (CommandProvidingEvent) -> Void) -> any CommandProvidingObserverHandle
}
