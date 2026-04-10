import MagicKit
import SwiftUI

/// 可配置的消息气泡样式参数，用于插件侧按需微调。
struct AppMessageBubbleStyle {
    var contentPadding: CGFloat = 10
    var assistantTrailingPadding: CGFloat = 20
    var cornerRadius: CGFloat = DesignTokens.Radius.md
    var errorBackground: Color = DesignTokens.Color.semantic.error.opacity(0.1)
    var userBackground: Color = DesignTokens.Color.semantic.info.opacity(0.1)
    var assistantBackground: Color = .clear
    var defaultBackground: Color = DesignTokens.Color.semantic.textTertiary.opacity(0.1)
    var errorForeground: Color = DesignTokens.Color.semantic.error
    var defaultForeground: Color = DesignTokens.Color.semantic.textPrimary
    var backgroundOverride: Color?
    var foregroundOverride: Color?

    static let `default` = AppMessageBubbleStyle()
}

/// 通用消息气泡容器样式。
struct AppMessageBubbleModifier: ViewModifier {
    let role: MessageRole
    let isError: Bool
    let style: AppMessageBubbleStyle

    func body(content: Content) -> some View {
        content
            .padding(style.contentPadding)
            .padding(.trailing, role == .assistant ? style.assistantTrailingPadding : 0)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: style.cornerRadius,
                    style: .continuous
                )
            )
    }

    private var backgroundColor: Color {
        if let override = style.backgroundOverride {
            return override
        }
        if isError {
            return style.errorBackground
        }
        switch role {
        case .user:
            return style.userBackground
        case .assistant:
            return style.assistantBackground
        default:
            return style.defaultBackground
        }
    }

    private var foregroundColor: Color {
        if let override = style.foregroundOverride {
            return override
        }
        if isError {
            return style.errorForeground
        }
        return style.defaultForeground
    }
}

extension View {
    func appMessageBubble(
        role: MessageRole,
        isError: Bool,
        style: AppMessageBubbleStyle = .default
    ) -> some View {
        modifier(AppMessageBubbleModifier(role: role, isError: isError, style: style))
    }
}
