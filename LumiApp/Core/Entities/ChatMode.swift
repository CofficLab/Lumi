import Foundation

/// 聊天模式
/// 定义用户在对话中的意图和权限
public enum ChatMode: String, CaseIterable, Codable, Identifiable, Sendable {
    /// 对话模式 - 只聊天，不执行任何工具或修改
    case chat = "chat"

    /// 构建模式 - 可以执行工具、修改代码，高风险需要用户确认
    case build = "build"

    /// 自主模式 - 可以执行工具、修改代码，高风险自动批准
    case autonomous = "autonomous"

    public var id: String { rawValue }

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
