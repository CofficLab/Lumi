import SwiftUI

/// Markdown 渲染主题配置
/// 用于自定义不同场景（如编辑器预览、聊天消息）的样式
public struct MarkdownTheme: Sendable {
    /// 标题字体回调
    public let headingFont: @Sendable (Int) -> Font
    /// 正文字体
    public let bodyFont: Font
    /// 代码块字体
    public let codeFont: Font
    /// 块间距
    public let blockSpacing: CGFloat
    /// 列表项间距
    public let listItemSpacing: CGFloat
    /// 代码块背景色
    public let codeBlockBackground: Color
    /// 引用块边框色
    public let quoteBorderColor: Color
    /// 表头背景色
    public let tableHeaderBackground: Color
    /// 是否显示代码块语言标签
    public let showLanguageLabel: Bool
    
    /// 默认主题（标准系统字体和间距）
    public static let standard = MarkdownTheme(
        headingFont: { level in
            switch level {
            case 1: return .system(size: 24, weight: .bold)
            case 2: return .system(size: 20, weight: .semibold)
            case 3: return .system(size: 18, weight: .semibold)
            default: return .system(size: 16, weight: .semibold)
            }
        },
        bodyFont: .system(size: 14),
        codeFont: .system(size: 13, design: .monospaced),
        blockSpacing: 10,
        listItemSpacing: 4,
        codeBlockBackground: Color.secondary.opacity(0.05),
        quoteBorderColor: Color.secondary.opacity(0.4),
        tableHeaderBackground: Color.secondary.opacity(0.1),
        showLanguageLabel: true
    )
    
    public init(
        headingFont: @escaping @Sendable (Int) -> Font = MarkdownTheme.standard.headingFont,
        bodyFont: Font = MarkdownTheme.standard.bodyFont,
        codeFont: Font = MarkdownTheme.standard.codeFont,
        blockSpacing: CGFloat = MarkdownTheme.standard.blockSpacing,
        listItemSpacing: CGFloat = MarkdownTheme.standard.listItemSpacing,
        codeBlockBackground: Color = MarkdownTheme.standard.codeBlockBackground,
        quoteBorderColor: Color = MarkdownTheme.standard.quoteBorderColor,
        tableHeaderBackground: Color = MarkdownTheme.standard.tableHeaderBackground,
        showLanguageLabel: Bool = MarkdownTheme.standard.showLanguageLabel
    ) {
        self.headingFont = headingFont
        self.bodyFont = bodyFont
        self.codeFont = codeFont
        self.blockSpacing = blockSpacing
        self.listItemSpacing = listItemSpacing
        self.codeBlockBackground = codeBlockBackground
        self.quoteBorderColor = quoteBorderColor
        self.tableHeaderBackground = tableHeaderBackground
        self.showLanguageLabel = showLanguageLabel
    }
}
