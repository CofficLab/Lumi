import SwiftUI

// MARK: - 玻璃按钮
///
/// 玻璃态按钮，提供优雅的交互反馈。
///
struct GlassButton: View {
    // MARK: - 配置
    enum Style {
        case primary
        case secondary
        case ghost
        case danger
    }

    let title: LocalizedStringKey
    let style: Style
    let action: () -> Void

    @State private var isHovering = false
    @State private var isPressing = false

    // MARK: - 主体
    var body: some View {
        Button(action: action) {
            buttonLabel
        }
        .buttonStyle(GlassButtonStyle(
            style: style,
            isHovering: $isHovering,
            isPressing: $isPressing
        ))
    }

    private var buttonLabel: some View {
        Text(title)
            .font(buttonFont)
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

    private var buttonForegroundColor: SwiftUI.Color {
        switch style {
        case .primary:
            return DesignTokens.Color.basePalette.deepBackground
        case .secondary:
            return DesignTokens.Color.semantic.textPrimary
        case .ghost:
            return DesignTokens.Color.semantic.textSecondary
        case .danger:
            return DesignTokens.Color.semantic.error
        }
    }

    @ViewBuilder private var buttonBackground: some View {
        switch style {
        case .primary:
            DesignTokens.Color.gradients.energyGradient
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
            DesignTokens.Color.semantic.error
                .opacity(isPressing ? 0.8 : (isHovering ? 0.9 : 0.7))
        }
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: buttonCornerRadius)
            .stroke(
                LinearGradient(
                    colors: [
                        SwiftUI.Color.clear,
                        SwiftUI.Color.white.opacity(0.1),
                        SwiftUI.Color.clear
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

// MARK: - 按钮样式
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

// MARK: - 预览
#Preview("玻璃按钮") {
    VStack(spacing: DesignTokens.Spacing.lg) {
        GlassButton(title: "主按钮", style: .primary) {}
        GlassButton(title: "次按钮", style: .secondary) {}
        GlassButton(title: "幽灵按钮", style: .ghost) {}
        GlassButton(title: "危险按钮", style: .danger) {}
    }
    .padding(DesignTokens.Spacing.lg)
    .frame(width: 200)
    .background(DesignTokens.Color.basePalette.deepBackground)
}
