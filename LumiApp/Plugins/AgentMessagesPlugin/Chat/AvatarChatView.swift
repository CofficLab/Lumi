import SwiftUI
import MagicKit
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
@MainActor
public enum AvatarView {
    /// 助手头像
    public static var assistant: some View {
        AppAvatar(
            systemImage: "cpu",
            tint: AppUI.Color.semantic.primary,
            backgroundTint: AppUI.Color.semantic.primary.opacity(0.1)
        )
    }

    /// 用户头像
    public static var user: some View {
        AppAvatar(
            systemImage: "person.fill",
            tint: AppUI.Color.semantic.info,
            backgroundTint: AppUI.Color.semantic.info.opacity(0.1)
        )
    }

    /// 工具头像
    public static var tool: some View {
        AppAvatar(
            systemImage: "gearshape.2.fill",
            tint: AppUI.Color.semantic.textTertiary,
            backgroundTint: AppUI.Color.semantic.textTertiary.opacity(0.1)
        )
    }

    /// 状态头像（连接中/等待响应/生成中等 UI 状态）
    public static var status: some View {
        AppAvatar(
            systemImage: "sparkles",
            tint: AppUI.Color.semantic.warning,
            backgroundTint: AppUI.Color.semantic.warning.opacity(0.12)
        )
    }

    /// 系统头像（系统提示/系统消息）
    public static var system: some View {
        AppAvatar(
            systemImage: "bolt.shield.fill",
            tint: AppUI.Color.semantic.textSecondary,
            backgroundTint: AppUI.Color.semantic.textSecondary.opacity(0.10)
        )
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
