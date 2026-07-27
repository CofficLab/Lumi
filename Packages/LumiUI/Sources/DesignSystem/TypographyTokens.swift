import SwiftUI

// MARK: - 字体系统
extension DesignTokens {
    /// 字体令牌 - 定义应用的排版规范
    public enum Typography {
        // MARK: - 标题
        public static let largeTitle = Font.system(size: 34, weight: .bold)
        public static let title1 = Font.system(size: 28, weight: .bold)
        public static let title2 = Font.system(size: 22, weight: .semibold)
        public static let title3 = Font.system(size: 20, weight: .semibold)

        // MARK: - 正文
        public static let body = Font.system(size: 15, weight: .regular)
        public static let bodyEmphasized = Font.system(size: 15, weight: .medium)
        public static let subheadline = Font.system(size: 13, weight: .regular)
        public static let callout = Font.system(size: 16, weight: .medium)

        // MARK: - 辅助
        public static let footnote = Font.system(size: 13, weight: .regular)
        public static let caption1 = Font.system(size: 12, weight: .regular)
        public static let caption2 = Font.system(size: 11, weight: .regular)

        // MARK: - 代码
        public static let code = Font.system(size: 13, weight: .regular, design: .monospaced)
    }
}
