import SwiftUI

// MARK: - 阴影系统
extension DesignTokens {
    /// 阴影令牌 - 定义界面元素的深度感和发光效果
    public enum Shadow {
        /// 微妙阴影 - 用于卡片
        public static let subtle = SwiftUI.Color.black.opacity(0.15)
        public static let subtleRadius: CGFloat = 12
        public static let subtleOffset: CGFloat = 4

        /// 发光阴影 - 用于强调元素
        /// - Parameters:
        ///   - color: 光晕颜色
        ///   - radius: 光晕半径
        /// - Returns: 带透明度的颜色
        public static func glow(color: SwiftUI.Color, radius: CGFloat = 8) -> SwiftUI.Color {
            color.opacity(0.4)
        }

        /// 深度阴影 - 用于浮动元素
        public static let deep = SwiftUI.Color.black.opacity(0.25)
        public static let deepRadius: CGFloat = 20
        public static let deepOffset: CGFloat = 8

        // MARK: - 输入框内阴影

        /// 输入框内阴影的起始不透明度（四边最外圈）—— 等价于 tailwind 的 `shadow-inner`。
        ///
        /// 用计算属性而非 `static let`：明暗直接影响取值，缓存成常量后主题切换不会跟随。
        /// 亮色表面与黑色对比更强，用更低的不透明度才不会糊成一条硬边；暗色表面需要更深
        /// 才读得出凹陷。
        @MainActor
        public static var innerFieldOpacity: Double {
            AppThemeAppearanceResolver.effectiveColorScheme == .dark ? 0.55 : 0.20
        }

        /// 输入框内阴影的模糊半径：对齐 tailwind `shadow-inner` 的 `blur-radius: 4px`
        public static let innerFieldBlur: CGFloat = 2
        /// 输入框内阴影的垂直偏移：让顶边阴影强于底边，符合上方来光的直觉
        public static let innerFieldOffsetY: CGFloat = 2
        /// 挖空区域的内缩量：让阴影不至于被完全裁掉，是凹陷深度的主要调节项
        public static let innerFieldInset: CGFloat = 0
    }
}

// MARK: - 凹陷输入表面

public extension View {
    /// 在已填充的形状之上叠一层「内阴影」，让输入框/搜索框看起来低于所在容器。
    ///
    /// 做法与 CSS `inset` 阴影一致：先用阴影色填满整个形状，再在合成组里用一块
    /// 「内缩 + 下移 + 模糊」的形状以 `destinationOut` 挖掉中心，剩下的就是从四边
    /// 向内衰减的环形，与 tailwind 的 `shadow-inner` 视觉等价。
    ///
    /// 不用 `ShapeStyle.shadow(.inner(_:))` 直接作用在填充上的原因：它要求填充接近
    /// 不透明才能显出阴影，而这些输入框用的 `Material` 半透明材质与极淡的
    /// `appListRowBackground` 都不满足；偏偏 `Material` 上链式调用 `.shadow(_:)`
    /// 又会让材质退化成不透明白色。
    ///
    /// ```swift
    /// RoundedRectangle(cornerRadius: 8, style: .continuous)
    ///     .fill(DesignTokens.Material.glass.opacity(0.1))
    ///     .appInputSurface(cornerRadius: 8)
    /// ```
    ///
    /// - Parameter cornerRadius: 与底层形状一致的圆角，确保内阴影贴合边缘。
    func appInputSurface(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let shadowColor = SwiftUI.Color.black.opacity(DesignTokens.Shadow.innerFieldOpacity)

        return overlay(
            shape
                .fill(shadowColor)
                .mask(
                    Rectangle()
                        .fill(SwiftUI.Color.white)
                        .overlay(
                            shape
                                .fill(SwiftUI.Color.black)
                                .padding(DesignTokens.Shadow.innerFieldInset)
                                .offset(y: DesignTokens.Shadow.innerFieldOffsetY)
                                .blur(radius: DesignTokens.Shadow.innerFieldBlur)
                                .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                )
                .clipShape(shape)
                .allowsHitTesting(false)
        )
    }
}
