import SwiftUI

public struct AppButton: View {
    @LumiTheme private var theme

    public enum Style {
        case primary
        case secondary
        case ghost
        case tonal
    }

    public enum Size {
        case small
        case medium
    }

    struct Metrics: Equatable {
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
    }

    let title: Text
    let systemImage: String?
    let style: Style
    let size: Size
    let fillsWidth: Bool
    let action: () -> Void

    public init(
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

    public init(
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

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                title
            }
            .font(font)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    var metrics: Metrics {
        switch size {
        case .small:
            Metrics(horizontalPadding: 10, verticalPadding: 6)
        case .medium:
            Metrics(horizontalPadding: 14, verticalPadding: 10)
        }
    }

    private var font: Font {
        switch size {
        case .small:
            DesignTokens.Typography.caption1
        case .medium:
            DesignTokens.Typography.bodyEmphasized
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            .white
        case .secondary:
            theme.textPrimary
        case .ghost:
            theme.primary
        case .tonal:
            theme.textSecondary
        }
    }

    private var background: some View {
        Group {
            switch style {
            case .primary:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(theme.primary)
            case .secondary:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(DesignTokens.Material.glass)
            case .ghost:
                Color.clear
            case .tonal:
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(theme.textSecondary.opacity(0.10))
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
                    .stroke(theme.primary.opacity(0.25), lineWidth: 1)
            default:
                EmptyView()
            }
        }
    }
}
