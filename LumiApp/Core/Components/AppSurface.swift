import SwiftUI

/// 统一表面样式（背景材质 + 圆角 + 可选边框）。
enum AppSurfaceStyle {
    case glass
    case glassThick
    case glassUltraThick
    case subtle
    case custom(Color)
}

private struct AppSurfaceModifier: ViewModifier {
    let style: AppSurfaceStyle
    let cornerRadius: CGFloat
    let borderColor: Color?
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundFillStyle)
            )
            .overlay(borderOverlay)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var backgroundFillStyle: AnyShapeStyle {
        switch style {
        case .glass:
            return AnyShapeStyle(DesignTokens.Material.glass)
        case .glassThick:
            return AnyShapeStyle(DesignTokens.Material.glassThick)
        case .glassUltraThick:
            return AnyShapeStyle(DesignTokens.Material.glassUltraThick)
        case .subtle:
            return AnyShapeStyle(DesignTokens.Color.semantic.textSecondary.opacity(0.06))
        case let .custom(color):
            return AnyShapeStyle(color)
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if let borderColor {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: lineWidth)
        }
    }
}

extension View {
    func appSurface(
        style: AppSurfaceStyle = .glass,
        cornerRadius: CGFloat = DesignTokens.Radius.md,
        borderColor: Color? = nil,
        lineWidth: CGFloat = 1
    ) -> some View {
        modifier(
            AppSurfaceModifier(
                style: style,
                cornerRadius: cornerRadius,
                borderColor: borderColor,
                lineWidth: lineWidth
            )
        )
    }

    /// 统一圆角裁剪，避免业务层直接使用具体 Shape。
    func appClipRounded(_ cornerRadius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
