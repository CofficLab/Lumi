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
    }
}
