import SwiftUI

/// 通用按钮组件：统一常见按钮视觉风格。
struct AppButton: View {
    enum Style {
        case primary
        case secondary
        case ghost
        case tonal
    }

    enum Size {
        case small
        case medium
    }

    let title: Text
    let systemImage: String?
    let style: Style
    let size: Size
    let fillsWidth: Bool
    let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        style: Style = .secondary,
        size: Size = .medium,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = Text(title)
        self.systemImage = systemImage
        self.style = style
        self.size = size
        self.fillsWidth = fillsWidth
        self.action = action
    }

    init(
        _ title: String,
        systemImage: String? = nil,
        style: Style = .secondary,
        size: Size = .medium,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = Text(title)
        self.systemImage = systemImage
        self.style = style
        self.size = size
        self.fillsWidth = fillsWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                title
            }
            .font(font)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var font: Font {
        switch size {
        case .small: DesignTokens.Typography.caption1
        case .medium: DesignTokens.Typography.bodyEmphasized
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: 10
        case .medium: 14
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small: 6
        case .medium: 10
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return DesignTokens.Color.semantic.textPrimary
        case .ghost:
            return .accentColor
        case .tonal:
            return DesignTokens.Color.semantic.textSecondary
        }
    }

    private var background: some View {
        Group {
            switch style {
            case .primary:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(Color.accentColor)
            case .secondary:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(DesignTokens.Material.glass)
            case .ghost:
                Color.clear
            case .tonal:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.10))
            }
        }
    }

    private var border: some View {
        Group {
            switch style {
            case .secondary:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            case .ghost:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
            default:
                EmptyView()
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AppButton("主按钮", systemImage: "sparkles", style: .primary) {}
        AppButton("次按钮", style: .secondary) {}
        AppButton("幽灵按钮", style: .ghost) {}
        AppButton("标签按钮", style: .tonal, size: .small) {}
    }
    .padding()
    .inRootView()
}
