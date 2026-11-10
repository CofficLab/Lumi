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

    // MARK: - 代码块（V4）

    /// 代码块外壳上方间距。
    public let codeBlockTopSpacing: CGFloat
    /// 代码块外壳下方间距。
    public let codeBlockBottomSpacing: CGFloat
    /// 代码块圆角。
    public let codeBlockCornerRadius: CGFloat
    /// 代码块边框宽度。
    public let codeBlockBorderWidth: CGFloat
    /// 代码块 header 左内边距。
    public let codeBlockHeaderLeadingPadding: CGFloat
    /// 代码块 header 右内边距。
    public let codeBlockHeaderTrailingPadding: CGFloat
    /// 代码块 header 垂直内边距。
    public let codeBlockHeaderVerticalPadding: CGFloat
    /// 语言标签字号。
    public let codeBlockLanguageFontSize: CGFloat
    /// 语言标签是否等宽。
    public let codeBlockLanguageIsMonospaced: Bool
    /// 语言标签是否转小写。
    public let codeBlockLanguageIsLowercase: Bool
    /// 语言标签是否截断。
    public let codeBlockLanguageTruncates: Bool
    /// 缺省语言标签。
    public let codeBlockDefaultLanguage: String
    /// header 文件图标尺寸。
    public let codeBlockHeaderFileIconSize: CGFloat
    /// header 操作按钮边长。
    public let codeBlockHeaderActionButtonSize: CGFloat
    /// header 操作按钮图标尺寸。
    public let codeBlockHeaderActionIconSize: CGFloat
    /// 代码内容水平内边距。
    public let codeBlockContentHorizontalPadding: CGFloat
    /// 代码内容上方内边距。
    public let codeBlockContentTopPadding: CGFloat
    /// 代码内容下方内边距。
    public let codeBlockContentBottomPadding: CGFloat
    /// 代码字号。
    public let codeBlockFontSize: CGFloat
    /// 是否显示行号。
    public let codeBlockShowsLineNumbers: Bool
    /// 是否自动换行。
    public let codeBlockWrapsLines: Bool
    /// 固定最大高度；nil 表示不设限。
    public let codeBlockMaxHeight: CGFloat?
    /// 复制反馈时长（毫秒）。
    public let codeBlockCopyFeedbackMilliseconds: Int
    /// 流式期间是否高亮。
    public let codeBlockHighlightsWhileStreaming: Bool

    // MARK: - 表格（V4）

    /// 表格圆角。
    public let tableCornerRadius: CGFloat
    /// 表格边框宽度。
    public let tableBorderWidth: CGFloat
    /// 单元格水平内边距。
    public let tableCellHorizontalPadding: CGFloat
    /// 单元格垂直内边距。
    public let tableCellVerticalPadding: CGFloat
    /// 表头字号。
    public let tableHeaderFontSize: CGFloat
    /// 表头字重。
    public let tableHeaderWeight: Font.Weight
    /// 表头对齐。
    public let tableHeaderAlignment: Alignment
    /// 单元格最小宽度。
    public let tableCellMinWidth: CGFloat
    /// 单元格最大宽度。
    public let tableCellMaxWidth: CGFloat
    /// 表格是否内部横向滚动。
    public let tableScrollsHorizontally: Bool

    // MARK: - 图片（V4）

    /// 图片最大宽度占容器的比例。
    public let imageMaxWidthFraction: CGFloat
    /// 图片最大高度。
    public let imageMaxHeight: CGFloat
    /// 图片圆角。
    public let imageCornerRadius: CGFloat
    /// 连续图片是否组成 gallery。
    public let imagesFormGallery: Bool
    /// 图片加载失败是否显示错误占位。
    public let imageShowsErrorPlaceholder: Bool

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
    /// - Important: 刻意**不**做成 `static let`：静态初始化可能发生在
    ///   非主线程的测试宿主里，`NSFont` 的度量访问在那里并不安全。
    ///   改为惰性求值后，字体度量只在真正首次访问时发生。
    ///
    ///   惰性求值必须**线程安全**：Swift Testing 默认并行执行，
    ///   多个用例同时首次访问 `zcode` 时若都去读 `NSFont`，
    ///   AppKit 的字体度量在并发下并不安全 —— 表现为进程 SIGSEGV。
    ///   因此这里用锁把「计算 + 缓存」做成原子操作，
    ///   并且**只在锁内**访问 `NSFont`。
    ///
    ///   缓存还有第二个作用：若 `NSFont` 的行高在进程生命周期内有极小波动，
    ///   重算会让「同一主题的两个实例」出现不同的 `bodyLineSpacing`。
    ///   缓存第一次的结果，保证同一进程内取值恒定。
    public static var zcode: MarkdownTheme {
        zcodeLock.lock()
        defer { zcodeLock.unlock() }
        if let cached = cachedZCode {
            return cached
        }
        let theme = makeZCodeTheme()
        cachedZCode = theme
        return theme
    }

    /// 保护字体度量的读取。
    ///
    /// - Important: 与 `zcodeLock` 分开，避免 `zcode` → `lineSpacing` 的嵌套死锁。
    private static let fontMetricsLock = NSLock()

    /// 保护 V4 主题的惰性初始化。
    ///
    /// - Important: 锁必须覆盖**整个**「检查缓存 → 计算 → 写缓存」过程，
    ///   只保护写入是不够的 —— 两个线程可能同时通过 `nil` 检查，
    ///   然后都去读 `NSFont`。
    private static let zcodeLock = NSLock()

    /// 缓存的 V4 主题；nil 表示尚未计算。
    ///
    /// - Note: 只在 `zcodeLock` 保护下读写，锁保证了互斥与可见性。
    ///   仍需 `nonisolated(unsafe)` 只是为了通过 Swift 6 的并发检查 ——
    ///   该检查无法静态推断「锁保护」这一事实。
    private nonisolated(unsafe) static var cachedZCode: MarkdownTheme?

    /// 构造 V4 主题。
    private static func makeZCodeTheme() -> MarkdownTheme {
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
            bodyLineSpacing: lineSpacing(targetLineHeight: 24.5, fontSize: 14),
            codeBlockTopSpacing: 16,
            codeBlockBottomSpacing: 16,
            codeBlockCornerRadius: 12,
            codeBlockBorderWidth: 1,
            codeBlockHeaderLeadingPadding: 12,
            codeBlockHeaderTrailingPadding: 8,
            codeBlockHeaderVerticalPadding: 8,
            codeBlockLanguageFontSize: 12,
            codeBlockLanguageIsMonospaced: true,
            codeBlockLanguageIsLowercase: true,
            codeBlockLanguageTruncates: true,
            codeBlockDefaultLanguage: "text",
            codeBlockHeaderFileIconSize: 16,
            codeBlockHeaderActionButtonSize: 28,
            codeBlockHeaderActionIconSize: 14,
            codeBlockContentHorizontalPadding: 8,
            codeBlockContentTopPadding: 0,
            codeBlockContentBottomPadding: 12,
            codeBlockFontSize: 12,
            codeBlockShowsLineNumbers: false,
            codeBlockWrapsLines: false,
            codeBlockMaxHeight: nil,
            codeBlockCopyFeedbackMilliseconds: 2000,
            codeBlockHighlightsWhileStreaming: false,
            tableCornerRadius: 12,
            tableBorderWidth: 1,
            tableCellHorizontalPadding: 12,
            tableCellVerticalPadding: 8,
            tableHeaderFontSize: 14,
            tableHeaderWeight: .regular,
            tableHeaderAlignment: .leading,
            tableCellMinWidth: 64,
            tableCellMaxWidth: 448,
            tableScrollsHorizontally: true,
            imageMaxWidthFraction: 0.5,
            imageMaxHeight: 360,
            imageCornerRadius: 12,
            imagesFormGallery: true,
            imageShowsErrorPlaceholder: true
        )
    }

    /// 由目标行高与字体行高换算「额外行距」。
    ///
    /// - Important: SwiftUI 的 `.lineSpacing` 是额外间距，
    ///   因此不能把目标行高直接传进去。
    ///
    /// - Important: `NSFont` 的度量访问**不是线程安全的**。
    ///   这里用一把**独立的**锁串行化，避免 Swift Testing 并行执行时
    ///   多个用例同时读字体度量而导致崩溃。
    ///
    ///   - Note: 必须与 `zcodeLock` 分开。`zcode` 持有 `zcodeLock` 时会调用
    ///     本方法，而 `NSLock` **不可重入** —— 用同一把锁会直接死锁。
    static func lineSpacing(targetLineHeight: CGFloat, fontSize: CGFloat) -> CGFloat {
        fontMetricsLock.lock()
        defer { fontMetricsLock.unlock() }
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
        bodyLineSpacing: CGFloat = 4,
        codeBlockTopSpacing: CGFloat = 0,
        codeBlockBottomSpacing: CGFloat = 0,
        codeBlockCornerRadius: CGFloat = 6,
        codeBlockBorderWidth: CGFloat = 1,
        codeBlockHeaderLeadingPadding: CGFloat = 10,
        codeBlockHeaderTrailingPadding: CGFloat = 10,
        codeBlockHeaderVerticalPadding: CGFloat = 5,
        codeBlockLanguageFontSize: CGFloat = 10,
        codeBlockLanguageIsMonospaced: Bool = false,
        codeBlockLanguageIsLowercase: Bool = false,
        codeBlockLanguageTruncates: Bool = false,
        codeBlockDefaultLanguage: String = "",
        codeBlockHeaderFileIconSize: CGFloat = 0,
        codeBlockHeaderActionButtonSize: CGFloat = 18,
        codeBlockHeaderActionIconSize: CGFloat = 10,
        codeBlockContentHorizontalPadding: CGFloat = 0,
        codeBlockContentTopPadding: CGFloat = 0,
        codeBlockContentBottomPadding: CGFloat = 0,
        codeBlockFontSize: CGFloat = 13,
        codeBlockShowsLineNumbers: Bool = false,
        codeBlockWrapsLines: Bool = false,
        codeBlockMaxHeight: CGFloat? = nil,
        codeBlockCopyFeedbackMilliseconds: Int = 2000,
        codeBlockHighlightsWhileStreaming: Bool = true,
        tableCornerRadius: CGFloat = 6,
        tableBorderWidth: CGFloat = 1,
        tableCellHorizontalPadding: CGFloat = 10,
        tableCellVerticalPadding: CGFloat = 8,
        tableHeaderFontSize: CGFloat = 12,
        tableHeaderWeight: Font.Weight = .semibold,
        tableHeaderAlignment: Alignment = .leading,
        tableCellMinWidth: CGFloat = 0,
        tableCellMaxWidth: CGFloat = 0,
        tableScrollsHorizontally: Bool = false,
        imageMaxWidthFraction: CGFloat = 1,
        imageMaxHeight: CGFloat = 0,
        imageCornerRadius: CGFloat = 0,
        imagesFormGallery: Bool = false,
        imageShowsErrorPlaceholder: Bool = false
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
        self.codeBlockTopSpacing = codeBlockTopSpacing
        self.codeBlockBottomSpacing = codeBlockBottomSpacing
        self.codeBlockCornerRadius = codeBlockCornerRadius
        self.codeBlockBorderWidth = codeBlockBorderWidth
        self.codeBlockHeaderLeadingPadding = codeBlockHeaderLeadingPadding
        self.codeBlockHeaderTrailingPadding = codeBlockHeaderTrailingPadding
        self.codeBlockHeaderVerticalPadding = codeBlockHeaderVerticalPadding
        self.codeBlockLanguageFontSize = codeBlockLanguageFontSize
        self.codeBlockLanguageIsMonospaced = codeBlockLanguageIsMonospaced
        self.codeBlockLanguageIsLowercase = codeBlockLanguageIsLowercase
        self.codeBlockLanguageTruncates = codeBlockLanguageTruncates
        self.codeBlockDefaultLanguage = codeBlockDefaultLanguage
        self.codeBlockHeaderFileIconSize = codeBlockHeaderFileIconSize
        self.codeBlockHeaderActionButtonSize = codeBlockHeaderActionButtonSize
        self.codeBlockHeaderActionIconSize = codeBlockHeaderActionIconSize
        self.codeBlockContentHorizontalPadding = codeBlockContentHorizontalPadding
        self.codeBlockContentTopPadding = codeBlockContentTopPadding
        self.codeBlockContentBottomPadding = codeBlockContentBottomPadding
        self.codeBlockFontSize = codeBlockFontSize
        self.codeBlockShowsLineNumbers = codeBlockShowsLineNumbers
        self.codeBlockWrapsLines = codeBlockWrapsLines
        self.codeBlockMaxHeight = codeBlockMaxHeight
        self.codeBlockCopyFeedbackMilliseconds = codeBlockCopyFeedbackMilliseconds
        self.codeBlockHighlightsWhileStreaming = codeBlockHighlightsWhileStreaming
        self.tableCornerRadius = tableCornerRadius
        self.tableBorderWidth = tableBorderWidth
        self.tableCellHorizontalPadding = tableCellHorizontalPadding
        self.tableCellVerticalPadding = tableCellVerticalPadding
        self.tableHeaderFontSize = tableHeaderFontSize
        self.tableHeaderWeight = tableHeaderWeight
        self.tableHeaderAlignment = tableHeaderAlignment
        self.tableCellMinWidth = tableCellMinWidth
        self.tableCellMaxWidth = tableCellMaxWidth
        self.tableScrollsHorizontally = tableScrollsHorizontally
        self.imageMaxWidthFraction = imageMaxWidthFraction
        self.imageMaxHeight = imageMaxHeight
        self.imageCornerRadius = imageCornerRadius
        self.imagesFormGallery = imagesFormGallery
        self.imageShowsErrorPlaceholder = imageShowsErrorPlaceholder
    }
}
