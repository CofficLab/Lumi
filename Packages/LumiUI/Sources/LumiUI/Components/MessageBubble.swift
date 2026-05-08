import SwiftUI

public enum MessageBubbleRole {
    case user
    case assistant
    case tool
    case status
    case error
    case system
    case other
}

public struct AppMessageBubbleStyle: @unchecked Sendable {
    public var contentPadding: CGFloat
    public var assistantTrailingPadding: CGFloat
    public var cornerRadius: CGFloat
    public var errorBackground: Color
    public var userBackground: Color
    public var assistantBackground: Color
    public var defaultBackground: Color
    public var errorForeground: Color
    public var defaultForeground: Color
    public var backgroundOverride: Color?
    public var foregroundOverride: Color?

    public init(
        contentPadding: CGFloat = 10,
        assistantTrailingPadding: CGFloat = 20,
        cornerRadius: CGFloat = 16,
        errorBackground: Color = Color(hex: "FF453A").opacity(0.1),
        userBackground: Color = Color(hex: "0A84FF").opacity(0.1),
        assistantBackground: Color = .clear,
        defaultBackground: Color = Color(hex: "98989E").opacity(0.1),
        errorForeground: Color = Color(hex: "FF453A"),
        defaultForeground: Color = Color.adaptive(light: "1C1C1E", dark: "FFFFFF"),
        backgroundOverride: Color? = nil,
        foregroundOverride: Color? = nil
    ) {
        self.contentPadding = contentPadding
        self.assistantTrailingPadding = assistantTrailingPadding
        self.cornerRadius = cornerRadius
        self.errorBackground = errorBackground
        self.userBackground = userBackground
        self.assistantBackground = assistantBackground
        self.defaultBackground = defaultBackground
        self.errorForeground = errorForeground
        self.defaultForeground = defaultForeground
        self.backgroundOverride = backgroundOverride
        self.foregroundOverride = foregroundOverride
    }

    public static let `default` = AppMessageBubbleStyle()
}

public struct AppMessageBubbleModifier: ViewModifier {
    let role: MessageBubbleRole
    let isError: Bool
    let style: AppMessageBubbleStyle

    public init(
        role: MessageBubbleRole,
        isError: Bool,
        style: AppMessageBubbleStyle = .default
    ) {
        self.role = role
        self.isError = isError
        self.style = style
    }

    public func body(content: Content) -> some View {
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

public extension View {
    func appMessageBubble(
        role: MessageBubbleRole,
        isError: Bool,
        style: AppMessageBubbleStyle = .default
    ) -> some View {
        modifier(AppMessageBubbleModifier(role: role, isError: isError, style: style))
    }
}
