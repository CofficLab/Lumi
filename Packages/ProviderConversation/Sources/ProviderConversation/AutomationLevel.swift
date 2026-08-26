import Foundation

/// 自动化等级（对话模式）：决定 Agent 能否执行工具、是否需要确认。
public enum AutomationLevel: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case chat
    case build
    case autonomous

    public var id: String { rawValue }

    public var rawValue: String {
        switch self { case .chat: "a1"; case .build: "a2"; case .autonomous: "a3" }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "a1", "chat": self = .chat
        case "a2", "build": self = .build
        case "a3", "autonomous": self = .autonomous
        default: return nil
        }
    }

    public var levelCode: String { rawValue.uppercased() }

    public var displayName: String {
        switch self { case .chat: "对话"; case .build: "构建"; case .autonomous: "自主" }
    }

    public var iconName: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .build: "hammer.fill"
        case .autonomous: "bolt.shield.fill"
        }
    }

    public var description: String {
        switch self {
        case .chat: "只进行对话，不执行任何工具"
        case .build: "可以执行工具，高风险需要确认"
        case .autonomous: "可以自主执行工具，持续推进任务"
        }
    }

    public var allowsTools: Bool {
        switch self { case .chat: false; case .build, .autonomous: true }
    }
}
