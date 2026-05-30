import Foundation

public enum ChatModeValue: String, CaseIterable, Identifiable, Sendable {
    case chat = "a1"
    case build = "a2"
    case autonomous = "a3"

    public var id: String { rawValue }

    public var levelCode: String { rawValue.uppercased() }

    public var iconName: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .build: return "hammer"
        case .autonomous: return "bolt"
        }
    }

    public var displayName: String {
        switch self {
        case .chat: return "Chat"
        case .build: return "Build"
        case .autonomous: return "Auto"
        }
    }
}

@MainActor
public enum ChatModeRuntime {
    public static var modeProvider: () -> ChatModeValue = { .build }
    public static var setMode: (ChatModeValue) -> Void = { _ in }

    public static var mode: ChatModeValue {
        modeProvider()
    }
}
