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
    @ViewBuilder
    func debugViewBadge(
        _ name: String,
        alignment: Alignment = .bottomLeading,
        rotationDegrees: Double = 0
    ) -> some View {
        overlay(alignment: alignment) {
            Text(name)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.purple.opacity(0.85)))
                .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                .padding(4)
                .rotationEffect(.degrees(rotationDegrees))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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
        rotationDegrees: Double = 0
    ) -> some View {
        self
    }
}
#endif