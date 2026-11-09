import AppKit
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
    /// 正文文字颜色（nil 时使用系统默认）
    public let textColor: Color?
    /// 次要文字颜色（用于引用内容、序号等，nil 时使用 .secondary）
    public let secondaryTextColor: Color?

    // MARK: - V4（ZCode）扩展项
    //
    // 以下参数全部位于 init 尾部并带旧默认值，
    // 因此 V1–V3 的既有调用方与 `MarkdownTheme.standard` 的每个字段都保持不变。

    /// 标题上方间距；nil 时沿用 `blockSpacing`。
    public let headingTopSpacing: CGFloat
    /// 标题下方间距；nil 时沿用 `blockSpacing`。
    public let headingBottomSpacing: CGFloat
    /// 首个块级子元素是否去掉顶部间距。
    public let firstChildRemovesTopSpacing: Bool
    /// 无序列表上方间距。
    public let unorderedListTopSpacing: CGFloat
    /// 无序列表下方间距。
    public let unorderedListBottomSpacing: CGFloat
    /// 无序列表左 padding。
    public let unorderedListLeadingPadding: CGFloat
    /// 嵌套列表上方间距。
    public let nestedListTopSpacing: CGFloat
    /// 嵌套列表下方间距。
    public let nestedListBottomSpacing: CGFloat
    /// 有序列表左 padding。
    public let orderedListLeadingPadding: CGFloat
    /// 有序列表条目左 padding。
    public let orderedListItemLeadingPadding: CGFloat
    /// 有序列表是否使用 inside decimal。
    public let orderedListUsesInsideDecimal: Bool
    /// 引用块上方间距。
    public let quoteTopSpacing: CGFloat
    /// 引用块下方间距。
    public let quoteBottomSpacing: CGFloat
    /// 引用块左边框宽度。
    public let quoteBorderWidth: CGFloat
    /// 引用块左 padding。
    public let quoteLeadingPadding: CGFloat
    /// 链接字号。
    public let linkFontSize: CGFloat
    /// 链接字重。
    public let linkWeight: Font.Weight
    /// 链接默认是否带下划线。
    public let linkHasUnderlineByDefault: Bool
    /// 链接下划线偏移。
    public let linkUnderlineOffset: CGFloat
    /// 行内代码字号。
    public let inlineCodeFontSize: CGFloat
    /// 行内代码圆角。
    public let inlineCodeCornerRadius: CGFloat
    /// 行内代码左右外边距。
    public let inlineCodeHorizontalMargin: CGFloat
    /// 行内代码水平 padding。
    public let inlineCodeHorizontalPadding: CGFloat
    /// 行内代码垂直 padding。
    public let inlineCodeVerticalPadding: CGFloat
    /// 正文目标行高。
    public let bodyTargetLineHeight: CGFloat
    /// 正文额外行距；由 `bodyTargetLineHeight` 与字体行高换算得到。
    public let bodyLineSpacing: CGFloat

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

    /// V4（ZCode）主题。
    ///
    /// 基准是 ZCode 3.15.1 计划第 2.4 节与
    /// `packages/ui/src/components/ai-elements/message.tsx:1367-1371`。
    ///
    /// - Note: 正文 `bodyLineSpacing` 由目标行高 24.5 减去字体自身行高得到；
    ///   SwiftUI 的 `.lineSpacing` 是「额外间距」，不能直接传 24.5。
    ///
    /// - Important: 刻意**不**做成 `static let`：`bodyLineSpacing` 需要读取
    ///   `NSFont` 的度量，而静态初始化可能发生在非主线程的测试宿主里，
    ///   AppKit 字体访问在那里并不安全。改为惰性求值后，字体度量只在
    ///   真正首次访问时发生。
    public static var zcode: MarkdownTheme {
        MarkdownTheme(
            headingFont: { level in
                switch level {
                case 1: return .system(size: 18, weight: .semibold)
                case 2: return .system(size: 16, weight: .semibold)
                case 3, 4: return .system(size: 14, weight: .semibold)
                case 5: return .system(size: 14, weight: .medium)
                default: return .system(size: 14, weight: .regular)
                }
            },
            bodyFont: .system(size: 14),
            codeFont: .system(size: 13, design: .monospaced),
            blockSpacing: 10,
            listItemSpacing: 6,
            headingTopSpacing: 24,
            headingBottomSpacing: 16,
            firstChildRemovesTopSpacing: true,
            unorderedListTopSpacing: 12,
            unorderedListBottomSpacing: 12,
            unorderedListLeadingPadding: 20,
            nestedListTopSpacing: 6,
            nestedListBottomSpacing: 6,
            orderedListLeadingPadding: 0,
            orderedListItemLeadingPadding: 4,
            orderedListUsesInsideDecimal: true,
            quoteTopSpacing: 16,
            quoteBottomSpacing: 16,
            quoteBorderWidth: 2,
            quoteLeadingPadding: 12,
            linkFontSize: 14,
            linkWeight: .medium,
            linkHasUnderlineByDefault: false,
            linkUnderlineOffset: 4,
            inlineCodeFontSize: 12,
            inlineCodeCornerRadius: 6,
            inlineCodeHorizontalMargin: 2,
            inlineCodeHorizontalPadding: 6,
            inlineCodeVerticalPadding: 2,
            bodyTargetLineHeight: 24.5,
            bodyLineSpacing: lineSpacing(targetLineHeight: 24.5, fontSize: 14)
        )
    }

    /// 由目标行高与字体行高换算「额外行距」。
    ///
    /// - Important: SwiftUI 的 `.lineSpacing` 是额外间距，
    ///   因此不能把目标行高直接传进去。
    static func lineSpacing(targetLineHeight: CGFloat, fontSize: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize)
        let fontLineHeight = font.ascender - font.descender + font.leading
        return max(0, targetLineHeight - fontLineHeight)
    }

    public init(
        headingFont: @escaping @Sendable (Int) -> Font = MarkdownTheme.standard.headingFont,
        bodyFont: Font = MarkdownTheme.standard.bodyFont,
        codeFont: Font = MarkdownTheme.standard.codeFont,
        blockSpacing: CGFloat = MarkdownTheme.standard.blockSpacing,
        listItemSpacing: CGFloat = MarkdownTheme.standard.listItemSpacing,
        codeBlockBackground: Color = MarkdownTheme.standard.codeBlockBackground,
        quoteBorderColor: Color = MarkdownTheme.standard.quoteBorderColor,
        tableHeaderBackground: Color = MarkdownTheme.standard.tableHeaderBackground,
        showLanguageLabel: Bool = MarkdownTheme.standard.showLanguageLabel,
        textColor: Color? = nil,
        secondaryTextColor: Color? = nil,
        // - Important: 下面这些新增参数的默认值**不能**写成
        //   `MarkdownTheme.standard.xxx`：`standard` 自身的初始化并没有覆盖它们，
        //   于是求值 `standard` 时又会回头求值 `standard` —— 静态初始化自引用，
        //   运行时表现为进程被 SIGTRAP 杀掉（signal 5），而不是编译错误。
        //   这里直接写与 `standard.blockSpacing` 相同的字面量 10。
        headingTopSpacing: CGFloat = 10,
        headingBottomSpacing: CGFloat = 10,
        firstChildRemovesTopSpacing: Bool = false,
        unorderedListTopSpacing: CGFloat = 10,
        unorderedListBottomSpacing: CGFloat = 10,
        unorderedListLeadingPadding: CGFloat = 0,
        nestedListTopSpacing: CGFloat = 10,
        nestedListBottomSpacing: CGFloat = 10,
        orderedListLeadingPadding: CGFloat = 0,
        orderedListItemLeadingPadding: CGFloat = 0,
        orderedListUsesInsideDecimal: Bool = false,
        quoteTopSpacing: CGFloat = 10,
        quoteBottomSpacing: CGFloat = 10,
        quoteBorderWidth: CGFloat = 1.5,
        quoteLeadingPadding: CGFloat = 0,
        linkFontSize: CGFloat = 14,
        linkWeight: Font.Weight = .regular,
        linkHasUnderlineByDefault: Bool = false,
        linkUnderlineOffset: CGFloat = 0,
        inlineCodeFontSize: CGFloat = 13,
        inlineCodeCornerRadius: CGFloat = 6,
        inlineCodeHorizontalMargin: CGFloat = 0,
        inlineCodeHorizontalPadding: CGFloat = 0,
        inlineCodeVerticalPadding: CGFloat = 0,
        bodyTargetLineHeight: CGFloat = 0,
        bodyLineSpacing: CGFloat = 4
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
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.headingTopSpacing = headingTopSpacing
        self.headingBottomSpacing = headingBottomSpacing
        self.firstChildRemovesTopSpacing = firstChildRemovesTopSpacing
        self.unorderedListTopSpacing = unorderedListTopSpacing
        self.unorderedListBottomSpacing = unorderedListBottomSpacing
        self.unorderedListLeadingPadding = unorderedListLeadingPadding
        self.nestedListTopSpacing = nestedListTopSpacing
        self.nestedListBottomSpacing = nestedListBottomSpacing
        self.orderedListLeadingPadding = orderedListLeadingPadding
        self.orderedListItemLeadingPadding = orderedListItemLeadingPadding
        self.orderedListUsesInsideDecimal = orderedListUsesInsideDecimal
        self.quoteTopSpacing = quoteTopSpacing
        self.quoteBottomSpacing = quoteBottomSpacing
        self.quoteBorderWidth = quoteBorderWidth
        self.quoteLeadingPadding = quoteLeadingPadding
        self.linkFontSize = linkFontSize
        self.linkWeight = linkWeight
        self.linkHasUnderlineByDefault = linkHasUnderlineByDefault
        self.linkUnderlineOffset = linkUnderlineOffset
        self.inlineCodeFontSize = inlineCodeFontSize
        self.inlineCodeCornerRadius = inlineCodeCornerRadius
        self.inlineCodeHorizontalMargin = inlineCodeHorizontalMargin
        self.inlineCodeHorizontalPadding = inlineCodeHorizontalPadding
        self.inlineCodeVerticalPadding = inlineCodeVerticalPadding
        self.bodyTargetLineHeight = bodyTargetLineHeight
        self.bodyLineSpacing = bodyLineSpacing
    }
}
