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
        overlay(alignment: alignment) {
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