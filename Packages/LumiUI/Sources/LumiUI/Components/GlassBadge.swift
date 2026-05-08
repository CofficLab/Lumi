import SwiftUI

public struct GlassBadge: View {
    public enum Style {
        case neutral
        case success
        case warning
        case error
        case info
        case glow(SwiftUI.Color)
    }

    let text: LocalizedStringKey
    let style: Style

    public init(text: LocalizedStringKey, style: Style) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(DesignTokens.Typography.caption1)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(background)
            .overlay(border)
            .cornerRadius(DesignTokens.Radius.full)
    }

    private var foregroundColor: SwiftUI.Color {
        switch style {
        case .neutral: DesignTokens.Color.semantic.textSecondary
        case .success: DesignTokens.Color.semantic.success
        case .warning: DesignTokens.Color.semantic.warning
        case .error: DesignTokens.Color.semantic.error
        case .info: DesignTokens.Color.semantic.info
        case let .glow(color): color
        }
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .neutral:
            RoundedRectangle(cornerRadius: DesignTokens.Radius.full)
                .fill(DesignTokens.Material.glass.opacity(0.15))
        case .success:
            DesignTokens.Color.semantic.success.opacity(0.15)
        case .warning:
            DesignTokens.Color.semantic.warning.opacity(0.15)
        case .error:
            DesignTokens.Color.semantic.error.opacity(0.15)
        case .info:
            DesignTokens.Color.semantic.info.opacity(0.15)
        case let .glow(color):
            color.opacity(0.2)
        }
    }

    private var borderColor: SwiftUI.Color {
        switch style {
        case .neutral: SwiftUI.Color.white
        case .success: DesignTokens.Color.semantic.success
        case .warning: DesignTokens.Color.semantic.warning
        case .error: DesignTokens.Color.semantic.error
        case .info: DesignTokens.Color.semantic.info
        case let .glow(color): color
        }
    }

    @ViewBuilder private var border: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.full)
            .stroke(borderColor.opacity(0.2), lineWidth: 1)
    }
}
