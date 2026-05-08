import SwiftUI

public struct GlassButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @LumiTheme private var theme

    public enum Style {
        case primary
        case secondary
        case ghost
        case danger
    }

    let title: LocalizedStringKey?
    let systemImage: String?
    let tableName: String?
    let style: Style
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressing = false

    public init(
        title: LocalizedStringKey,
        tableName: String? = nil,
        style: Style,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = nil
        self.tableName = tableName
        self.style = style
        self.action = action
    }

    public init(systemImage: String, style: Style, action: @escaping () -> Void) {
        self.title = nil
        self.systemImage = systemImage
        self.tableName = nil
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            buttonLabel
        }
        .buttonStyle(
            GlassButtonStyle(
                style: style,
                isHovering: $isHovering,
                isPressing: $isPressing
            )
        )
    }

    private var buttonLabel: some View {
        Group {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(buttonFont.bold())
            } else if let title = title {
                Text(title, tableName: tableName)
                    .font(buttonFont)
            }
        }
        .foregroundColor(buttonForegroundColor)
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.sm)
        .background(buttonBackground)
        .overlay(buttonBorder)
        .cornerRadius(buttonCornerRadius)
        .scaleEffect(isPressing ? 0.97 : 1.0)
        .animation(.spring(response: 0.3), value: isPressing)
    }

    private var buttonFont: Font {
        switch style {
        case .primary, .secondary:
            return DesignTokens.Typography.bodyEmphasized
        case .ghost, .danger:
            return DesignTokens.Typography.body
        }
    }

    private var buttonForegroundColor: Color {
        switch style {
        case .primary:
            return theme.background
        case .secondary:
            return theme.textPrimary
        case .ghost:
            return theme.textSecondary
        case .danger:
            return theme.error
        }
    }

    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .primary:
            theme.energyGradient
                .opacity(isPressing ? 0.8 : (isHovering ? 1.0 : 0.9))
        case .secondary:
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Material.glass)
                .opacity(isHovering ? 0.15 : 0.1)
        case .ghost:
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Material.glass)
                .opacity(isHovering ? 0.1 : 0.05)
        case .danger:
            theme.error.opacity(colorScheme == .light ? 0.1 : 0.2)
                .opacity(isPressing ? 1.0 : (isHovering ? 0.8 : 0.6))
        }
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: buttonCornerRadius)
            .stroke(
                LinearGradient(
                    colors: [
                        .clear,
                        .white.opacity(0.1),
                        .clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .opacity(isHovering ? 1.0 : 0.5)
    }

    private var buttonCornerRadius: CGFloat {
        DesignTokens.Radius.sm
    }
}

private struct GlassButtonStyle: ButtonStyle {
    let style: GlassButton.Style
    @Binding var isHovering: Bool
    @Binding var isPressing: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onHover { hovering in
                isHovering = hovering
            }
            .onChange(of: configuration.isPressed) { _, isPressed in
                isPressing = isPressed
            }
    }
}
