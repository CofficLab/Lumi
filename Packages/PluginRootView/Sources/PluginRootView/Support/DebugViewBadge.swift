import SwiftUI

/// 调试辅助：在视图角落叠加一个显示区域名字的 badge。
///
/// 仅用于 Debug 构建下肉眼识别当前区域由哪个视图渲染。
/// Release 构建下 `debugViewBadge(_:alignment:)` 为空操作，不影响线上行为。
#if DEBUG
extension View {
    /// 在 DEBUG 构建下，于视图指定角落叠加显示 `name` 的调试 badge。
    ///
    /// 通过 `.overlay(alignment:)` 实现，不改变原视图布局；badge 本身
    /// `allowsHitTesting(false)`，不拦截任何交互，且对辅助功能隐藏。
    ///
    /// 嵌套区域各自带 badge 时，用不同的 `alignment` 避免相互遮挡。
    /// 窄区域（如竖排侧边栏）可传 `rotationDegrees: 90` 让文字竖排，避免被裁切。
    ///
    /// 颜色默认由 `name` 哈希得到，同名区域颜色稳定，不同名区域相互区分，
    /// 便于一眼分辨嵌套层级；需要精确控制时可传 `color`。
    @ViewBuilder
    func debugViewBadge(
        _ name: String,
        alignment: Alignment = .bottomLeading,
        rotationDegrees: Double = 0,
        color: Color? = nil
    ) -> some View {
        // 旋转后的 badge 尺寸（宽高互换）与容器尺寸不匹配时，交给自定义 Layout 排布：
        // 直接 overlay 时 overlay 只拿到与容器等大的尺寸提议，旋转后超出的部分会被裁切，
        // 这里让 Layout 自行测量并按需超出容器绘制。
        if rotationDegrees == 0 {
            overlay(alignment: alignment) {
                badgeLabel(name, rotationDegrees: 0, color: color)
            }
        } else {
            overlay {
                BadgeOverflowLayout(alignment: alignment, rotationDegrees: rotationDegrees) {
                    badgeLabel(name, rotationDegrees: rotationDegrees, color: color)
                }
            }
        }
    }

    /// badge 本体；`allowsHitTesting(false)` 且对辅助功能隐藏，不干扰宿主交互。
    private func badgeLabel(
        _ name: String,
        rotationDegrees: Double,
        color: Color?
    ) -> some View {
        Text(name)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill((color ?? badgeColor(for: name)).opacity(0.9))
            )
            .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
            .padding(4)
            .rotationEffect(.degrees(rotationDegrees))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// 由名称稳定映射到一个色相，避免所有 badge 颜色一致。
    ///
    /// 用 djb2 变体累加字符字节，与 UI 侧调试 badge 使用同一套映射逻辑。
    /// 饱和度/亮度固定，仅色相变化，保证白字始终可读。
    private func badgeColor(for name: String) -> Color {
        var hash: UInt64 = 5381
        for byte in name.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        // 跳过过暗的蓝紫色区间（hue 约 0.6~0.75），与半透明背景叠在一起不易辨识
        let hue = Double(hash % 1000) / 1000
        return Color(
            hue: hue < 0.6 || hue > 0.75 ? hue : (hue + 0.25).truncatingRemainder(dividingBy: 1),
            saturation: 0.65,
            brightness: 0.72
        )
    }
}

/// 旋转 badge 的排布布局。
///
/// `rotationEffect` 只影响绘制、不改变布局尺寸：布局仍按未旋转的尺寸（如 70pt 宽）
/// 排布，而视觉包围盒是旋转后的（如 15pt × 70pt）。两者不一致时，对齐会算错，
/// 导致 badge 溢出到容器外被父级/屏幕裁切。
///
/// 这里显式换算旋转后的包围盒参与对齐，并允许绘制超出父级边界。
private struct BadgeOverflowLayout: Layout {
    let alignment: Alignment
    let rotationDegrees: Double

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        return rotatedBoundsSize(subview.sizeThatFits(.unspecified))
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else { return }

        // 布局尺寸（未旋转）与视觉尺寸（旋转后）。
        let layoutSize = subview.sizeThatFits(.unspecified)
        let visualSize = rotatedBoundsSize(layoutSize)

        // 按视觉包围盒计算对齐目标点。
        let anchor = unitPoint(for: alignment)
        let ax = anchor.x
        let ay = anchor.y
        let dx = bounds.width - visualSize.width
        let dy = bounds.height - visualSize.height
        let targetCenter = CGPoint(
            x: bounds.minX + dx * ax + (0.5 - ax) * visualSize.width,
            y: bounds.minY + dy * ay + (0.5 - ay) * visualSize.height
        )

        // `place(at:anchor:)` 的 anchor 相对子视图自身的布局框，
        // 因此按布局尺寸反推放置点，使旋转后的视觉中心落在 targetCenter。
        let placePoint = CGPoint(
            x: targetCenter.x - (0.5 - ax) * layoutSize.width,
            y: targetCenter.y - (0.5 - ay) * layoutSize.height
        )

        subview.place(
            at: placePoint,
            anchor: anchor,
            proposal: ProposedViewSize(layoutSize)
        )
    }

    /// 旋转后的视觉包围盒尺寸。
    private func rotatedBoundsSize(_ size: CGSize) -> CGSize {
        let radians = rotationDegrees * .pi / 180
        let cosA = abs(cos(radians))
        let sinA = abs(sin(radians))
        // 0° / 180° 不改变包围盒。
        guard sinA > .ulpOfOne else { return size }
        return CGSize(
            width: size.width * cosA + size.height * sinA,
            height: size.width * sinA + size.height * cosA
        )
    }

    /// `Alignment` → `UnitPoint`（0 = leading/top，1 = trailing/bottom）。
    private func unitPoint(for alignment: Alignment) -> UnitPoint {
        switch alignment {
        case .leading, .topLeading, .bottomLeading:
            return UnitPoint(x: 0, y: alignment == .topLeading ? 0 : (alignment == .bottomLeading ? 1 : 0.5))
        case .trailing, .topTrailing, .bottomTrailing:
            return UnitPoint(x: 1, y: alignment == .topTrailing ? 0 : (alignment == .bottomTrailing ? 1 : 0.5))
        case .top:
            return UnitPoint(x: 0.5, y: 0)
        case .bottom:
            return UnitPoint(x: 0.5, y: 1)
        default:
            return UnitPoint(x: 0.5, y: 0.5)
        }
    }
}
#else
extension View {
    /// Release 构建下为空操作。
    @ViewBuilder
    func debugViewBadge(
        _ name: String,
        alignment: Alignment = .bottomLeading,
        rotationDegrees: Double = 0,
        color: Color? = nil
    ) -> some View {
        self
    }
}
#endif