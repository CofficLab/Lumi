import SwiftUI

// MARK: - 间距系统
extension DesignTokens {
    /// 间距令牌 - 定义应用中的标准间距和内边距
    public enum Spacing {
        /// 超小间距 (4pt)
        public static let xs: CGFloat = 4
        /// 小间距 (8pt)
        public static let sm: CGFloat = 8
        /// 中等间距 (16pt)
        public static let md: CGFloat = 16
        /// 大间距 (24pt)
        public static let lg: CGFloat = 24
        /// 超大间距 (32pt)
        public static let xl: CGFloat = 32
        /// 特大间距 (48pt)
        public static let xxl: CGFloat = 48

        /// 组件默认内边距 (16pt)
        public static let cardPadding = EdgeInsets(
            top: md,
            leading: md,
            bottom: md,
            trailing: md
        )

        /// 紧凑布局内边距 (8pt)
        public static let compactPadding = EdgeInsets(
            top: sm,
            leading: sm,
            bottom: sm,
            trailing: sm
        )

        /// 舒适布局内边距 (24pt)
        public static let comfortablePadding = EdgeInsets(
            top: lg,
            leading: lg,
            bottom: lg,
            trailing: lg
        )
    }
}
