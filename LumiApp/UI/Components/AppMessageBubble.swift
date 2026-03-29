import SwiftUI
import MagicKit

/// 通用消息气泡容器样式。
struct AppMessageBubbleModifier: ViewModifier {
    let role: MessageRole
    let isError: Bool

    func body(content: Content) -> some View {
        content
            .padding(10)
            .padding(.trailing, role == .assistant ? 20 : 0)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.Radius.md,
                    style: .continuous
                )
            )
    }

    private var backgroundColor: Color {
        if isError {
            return DesignTokens.Color.semantic.error.opacity(0.1)
        }
        switch role {
        case .user:
            return DesignTokens.Color.semantic.info.opacity(0.1)
        case .assistant:
            return DesignTokens.Color.semantic.textTertiary.opacity(0.12)
        default:
            return DesignTokens.Color.semantic.textTertiary.opacity(0.1)
        }
    }

    private var foregroundColor: Color {
        if isError {
            return DesignTokens.Color.semantic.error
        }
        return DesignTokens.Color.semantic.textPrimary
    }
}

extension View {
    func appMessageBubble(role: MessageRole, isError: Bool) -> some View {
        modifier(AppMessageBubbleModifier(role: role, isError: isError))
    }
}
