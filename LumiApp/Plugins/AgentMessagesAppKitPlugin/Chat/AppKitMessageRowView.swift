import SwiftUI
import MagicKit

/// AppKit 版消息行视图
/// 不依赖 AgentMessagesPlugin，但在布局和样式上尽量向 ChatBubble 看齐
struct AppKitMessageRowView: View {
    let message: ChatMessage

    // MARK: - Layout helpers

    private var isUser: Bool { message.role == .user }
    private var isAssistant: Bool { message.role == .assistant }
    private var isSystem: Bool { message.role == .system }

    private var bubbleBackground: Color {
        if message.isError {
            return Color.red.opacity(0.18)
        }
        if isUser {
            return Color.accentColor.opacity(0.18)
        }
        if isAssistant {
            return Color.white.opacity(0.06)
        }
        return Color.gray.opacity(0.15)
    }

    private var bubbleBorder: Color {
        if message.isError {
            return Color.red.opacity(0.45)
        }
        if isUser {
            return Color.accentColor.opacity(0.45)
        }
        if isAssistant {
            return Color.white.opacity(0.18)
        }
        return Color.gray.opacity(0.35)
    }

    private var avatarText: String {
        if isUser { return "U" }
        if isAssistant { return "A" }
        if isSystem { return "S" }
        return "·"
    }

    private var avatarColor: Color {
        if isUser { return .accentColor }
        if isAssistant { return .purple.opacity(0.7) }
        if isSystem { return .gray }
        return .secondary
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                header
                bubble
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    // MARK: - Subviews

    private var avatar: some View {
        Text(avatarText)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 22, height: 22)
            .background(avatarColor)
            .clipShape(Circle())
            .opacity(isSystem ? 0.7 : 1)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(roleTitle)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }

    private var roleTitle: String {
        switch message.role {
        case .user: return "User"
        case .assistant: return "Assistant"
        case .system: return "System"
        default: return "Message"
        }
    }

    private var bubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(message.isError ? .red : .primary)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(bubbleBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(bubbleBorder, lineWidth: 1)
            )
    }
}


