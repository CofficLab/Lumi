import Foundation

/// 聊天模式
/// 定义用户在对话中的意图和权限
public enum ChatMode: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    /// A1 对话模式 - 只聊天，不执行任何工具或修改
    case chat

    /// A2 构建模式 - 可以执行工具、修改代码，高风险需要用户确认
    case build

    /// A3 自主模式 - 可以执行工具、修改代码，高风险自动批准
    case autonomous

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .chat:
            return "a1"
        case .build:
            return "a2"
        case .autonomous:
            return "a3"
        }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "a1", "chat":
            self = .chat
        case "a2", "build":
            self = .build
        case "a3", "autonomous":
            self = .autonomous
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid chat mode: \(rawValue)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// 等级标识
    public var levelCode: String {
        rawValue.uppercased()
    }

    /// 显示名称
    public var displayName: String {
        switch self {
        case .chat:
            return "对话"
        case .build:
            return "构建"
        case .autonomous:
            return "自主"
        }
    }

    /// 英文显示名称
    public var displayNameEn: String {
        switch self {
        case .chat:
            return "Chat"
        case .build:
            return "Build"
        case .autonomous:
            return "Autonomous"
        }
    }

    /// 图标
    public var iconName: String {
        switch self {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .build:
            return "hammer.fill"
        case .autonomous:
            return "bolt.shield.fill"
        }
    }

    /// 描述
    public var description: String {
        switch self {
        case .chat:
            return "只进行对话，不执行任何操作"
        case .build:
            return "可以执行工具、修改代码，高风险需要确认"
        case .autonomous:
            return "可以执行工具、修改代码，高风险自动批准"
        }
    }

    /// 描述英文
    public var descriptionEn: String {
        switch self {
        case .chat:
            return "Chat only, no tool execution"
        case .build:
            return "Can execute tools, high-risk requires confirmation"
        case .autonomous:
            return "Can execute tools, high-risk auto-approved"
        }
    }

    /// 是否允许使用工具
    public var allowsTools: Bool {
        switch self {
        case .chat:
            return false
        case .build, .autonomous:
            return true
        }
    }

    /// 高风险是否自动批准
    public var autoApproveRisk: Bool {
        switch self {
        case .chat, .build:
            return false
        case .autonomous:
            return true
        }
    }

}
