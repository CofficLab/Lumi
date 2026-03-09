import Foundation

/// 聊天模式
/// 定义用户在对话中的意图和权限
public enum ChatMode: String, CaseIterable, Codable, Identifiable, Sendable {
    /// 对话模式 - 只聊天，不执行任何工具或修改
    case chat = "chat"

    /// 构建模式 - 可以执行工具、修改代码等
    case build = "build"

    /// 构建模式（多任务）- 可以执行工具、修改代码，并使用多 Worker 协作
    case buildMultiTask = "build_multi_task"

    public var id: String { rawValue }

    /// 显示名称
    public var displayName: String {
        switch self {
        case .chat:
            return "对话"
        case .build:
            return "构建"
        case .buildMultiTask:
            return "构建（多任务）"
        }
    }

    /// 英文显示名称
    public var displayNameEn: String {
        switch self {
        case .chat:
            return "Chat"
        case .build:
            return "Build"
        case .buildMultiTask:
            return "Build (Multi-Task)"
        }
    }

    /// 图标
    public var iconName: String {
        switch self {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .build:
            return "hammer.fill"
        case .buildMultiTask:
            return "hammer.fill"
        }
    }

    /// 描述
    public var description: String {
        switch self {
        case .chat:
            return "只进行对话，不执行任何操作"
        case .build:
            return "可以执行工具、修改代码"
        case .buildMultiTask:
            return "可以执行工具、修改代码，并使用多 Worker 协作"
        }
    }

    /// 描述英文
    public var descriptionEn: String {
        switch self {
        case .chat:
            return "Chat only, no tool execution"
        case .build:
            return "Can execute tools and modify code"
        case .buildMultiTask:
            return "Can execute tools, modify code, and use multi-worker collaboration"
        }
    }

    /// 是否允许使用工具
    public var allowsTools: Bool {
        switch self {
        case .chat:
            return false
        case .build, .buildMultiTask:
            return true
        }
    }

    /// 是否允许使用多 Worker 工具
    public var allowsMultiWorker: Bool {
        switch self {
        case .chat, .build:
            return false
        case .buildMultiTask:
            return true
        }
    }
}
