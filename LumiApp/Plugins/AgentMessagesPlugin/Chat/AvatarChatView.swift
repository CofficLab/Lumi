import SwiftUI
import Foundation

/// 聊天气泡头像视图 - 根据消息角色显示不同的头像
public struct AvatarChatView: View {
    public let role: MessageRole
    public let isToolOutput: Bool

    public init(role: MessageRole, isToolOutput: Bool) {
        self.role = role
        self.isToolOutput = isToolOutput
    }

    public var body: some View {
        Group {
            if isToolOutput || role == .tool {
                AvatarView.tool
            } else if role == .user {
                AvatarView.user
            } else if role == .status {
                AvatarView.status
            } else if role == .system {
                AvatarView.system
            } else {
                AvatarView.assistant
            }
        }
    }
}

// MARK: - Avatar View

/// 头像视图
public enum AvatarView {
    /// 助手头像
    public static var assistant: some View {
        Image(systemName: "cpu")
            .font(.system(size: 16))
            .foregroundColor(DesignTokens.Color.semantic.primary)
            .frame(width: 24, height: 24)
            .background(DesignTokens.Color.semantic.primary.opacity(0.1))
            .clipShape(Circle())
    }

    /// 用户头像
    public static var user: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 16))
            .foregroundColor(DesignTokens.Color.semantic.info)
            .frame(width: 24, height: 24)
            .background(DesignTokens.Color.semantic.info.opacity(0.1))
            .clipShape(Circle())
    }

    /// 工具头像
    public static var tool: some View {
        Image(systemName: "gearshape.2.fill")
            .font(.system(size: 16))
            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            .frame(width: 24, height: 24)
            .background(DesignTokens.Color.semantic.textTertiary.opacity(0.1))
            .clipShape(Circle())
    }

    /// 状态头像（连接中/等待响应/生成中等 UI 状态）
    public static var status: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 16))
            .foregroundColor(DesignTokens.Color.semantic.warning)
            .frame(width: 24, height: 24)
            .background(DesignTokens.Color.semantic.warning.opacity(0.12))
            .clipShape(Circle())
    }

    /// 系统头像（系统提示/系统消息）
    public static var system: some View {
        Image(systemName: "bolt.shield.fill")
            .font(.system(size: 16))
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            .frame(width: 24, height: 24)
            .background(DesignTokens.Color.semantic.textSecondary.opacity(0.10))
            .clipShape(Circle())
    }
}

#Preview("Assistant Avatar") {
    AvatarChatView(role: .assistant, isToolOutput: false)
        .padding()
        .background(Color.black)
}

#Preview("User Avatar") {
    AvatarChatView(role: .user, isToolOutput: false)
        .padding()
        .background(Color.black)
}

#Preview("Tool Avatar") {
    AvatarChatView(role: .system, isToolOutput: true)
        .padding()
        .background(Color.black)
}
