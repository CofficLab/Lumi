import SwiftUI

// MARK: - 圆角系统
extension DesignTokens {
    /// 圆角令牌 - 定义容器和组件的圆角半径
    public enum Radius {
        /// 小圆角 (8pt) - 适用于按钮、标签
        public static let sm: CGFloat = 8
        /// 中圆角 (16pt) - 适用于卡片
        public static let md: CGFloat = 16
        /// 大圆角 (24pt) - 适用于模态、面板
        public static let lg: CGFloat = 24
        /// 超大圆角 (32pt) - 适用于特殊容器
        public static let xl: CGFloat = 32
        /// 完全圆角 - 适用于药丸形状
        public static let full: CGFloat = .infinity
    }
}
