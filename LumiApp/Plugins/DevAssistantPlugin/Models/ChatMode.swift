import Foundation

/// 聊天模式
/// 定义用户在对话中的意图和权限
enum ChatMode: String, CaseIterable, Codable, Identifiable {
    /// 对话模式 - 只聊天，不执行任何工具或修改
    case chat = "chat"
    
    /// 构建模式 - 可以执行工具、修改代码等
    case build = "build"
    
    var id: String { rawValue }
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .chat:
            return "对话"
        case .build:
            return "构建"
        }
    }
    
    /// 英文显示名称
    var displayNameEn: String {
        switch self {
        case .chat:
            return "Chat"
        case .build:
            return "Build"
        }
    }
    
    /// 图标
    var iconName: String {
        switch self {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .build:
            return "hammer.fill"
        }
    }
    
    /// 描述
    var description: String {
        switch self {
        case .chat:
            return "只进行对话，不执行任何操作"
        case .build:
            return "可以执行工具、修改代码"
        }
    }
    
    /// 描述英文
    var descriptionEn: String {
        switch self {
        case .chat:
            return "Chat only, no tool execution"
        case .build:
            return "Can execute tools and modify code"
        }
    }
}