import Foundation
import SwiftUI
import Testing
@testable import KitMarkdown

/// V4（ZCode）Markdown 主题契约测试。
///
/// 基准是 ZCode 3.15.1 计划第 2.4 节与
/// `packages/ui/src/components/ai-elements/message.tsx:1367-1371`：
///
/// | 元素 | V4 规格 |
/// |---|---|
/// | 标题通用 | 上 24、下 16；首个子元素去顶部 margin |
/// | h1 | 18 / 600 |
/// | h2 | 16 / 600 |
/// | h3、h4 | 14 / 600 |
/// | h5 | 14 / 500 |
/// | h6 | 14 / 400 |
/// | 无序列表 | 上下 12、左 padding 20、项间距 6、subtlest marker；嵌套上下 6 |
/// | 有序列表 | inside decimal、左 padding 0、li 左 padding 4 |
/// | 引用 | 上下 16、左 2 border、左 padding 12、subtle 文本 |
/// | 链接 | 14/500、icon-blue、默认无 underline |
/// | 行内代码 | 12 mono、圆角 6、左右外边距 2、水平 padding 6、垂直 2 |
///
/// - Important: V1–V3 的默认值必须**逐字段相等**，
///   新参数只能加在 init 尾部并给旧默认值。
@Suite("ZCode Markdown 主题")
struct ZCodeMarkdownThemeTests {

    // MARK: - 旧主题不变

    @Test("MarkdownTheme.standard 的每个旧字段逐值不变")
    func standardThemeFieldsUnchanged() {
        let standard = MarkdownTheme.standard

        // 标题字号与字重。
        #expect(standard.headingFont(1) == .system(size: 24, weight: .bold))
        #expect(standard.headingFont(2) == .system(size: 20, weight: .semibold))
        #expect(standard.headingFont(3) == .system(size: 18, weight: .semibold))
        #expect(standard.headingFont(4) == .system(size: 16, weight: .semibold))
        #expect(standard.headingFont(6) == .system(size: 16, weight: .semibold))

        // 字体。
        #expect(standard.bodyFont == .system(size: 14))
        #expect(standard.codeFont == .system(size: 13, design: .monospaced))

        // 间距。
        #expect(standard.blockSpacing == 10)
        #expect(standard.listItemSpacing == 4)

        // 行为开关。
        #expect(standard.showLanguageLabel == true)
        #expect(standard.textColor == nil)
        #expect(standard.secondaryTextColor == nil)
    }

    @Test("用默认参数构造的主题等于 standard")
    func defaultInitializerEqualsStandard() {
        let theme = MarkdownTheme()

        #expect(theme.headingFont(1) == MarkdownTheme.standard.headingFont(1))
        #expect(theme.headingFont(2) == MarkdownTheme.standard.headingFont(2))
        #expect(theme.bodyFont == MarkdownTheme.standard.bodyFont)
        #expect(theme.codeFont == MarkdownTheme.standard.codeFont)
        #expect(theme.blockSpacing == MarkdownTheme.standard.blockSpacing)
        #expect(theme.listItemSpacing == MarkdownTheme.standard.listItemSpacing)
        #expect(theme.codeBlockBackground == MarkdownTheme.standard.codeBlockBackground)
        #expect(theme.quoteBorderColor == MarkdownTheme.standard.quoteBorderColor)
        #expect(theme.tableHeaderBackground == MarkdownTheme.standard.tableHeaderBackground)
        #expect(theme.showLanguageLabel == MarkdownTheme.standard.showLanguageLabel)
        #expect(theme.textColor == MarkdownTheme.standard.textColor)
        #expect(theme.secondaryTextColor == MarkdownTheme.standard.secondaryTextColor)
    }

    // MARK: - V4 标题

    @Test("V4 标题字号与字重符合规格")
    func zcodeHeadingTypography() {
        let theme = MarkdownTheme.zcode

        // h1 18/600、h2 16/600、h3 与 h4 14/600、h5 14/500、h6 14/400。
        #expect(theme.headingFont(1) == .system(size: 18, weight: .semibold))
        #expect(theme.headingFont(2) == .system(size: 16, weight: .semibold))
        #expect(theme.headingFont(3) == .system(size: 14, weight: .semibold))
        #expect(theme.headingFont(4) == .system(size: 14, weight: .semibold))
        #expect(theme.headingFont(5) == .system(size: 14, weight: .medium))
        #expect(theme.headingFont(6) == .system(size: 14, weight: .regular))
    }

    @Test("V4 标题上下间距是 24 与 16")
    func zcodeHeadingSpacing() {
        #expect(MarkdownTheme.zcode.headingTopSpacing == 24)
        #expect(MarkdownTheme.zcode.headingBottomSpacing == 16)
    }

    @Test("首个子元素没有顶部 margin")
    func firstChildHasNoTopMargin() {
        #expect(MarkdownTheme.zcode.firstChildRemovesTopSpacing == true)
    }

    // MARK: - V4 列表

    @Test("V4 无序列表规格")
    func zcodeUnorderedList() {
        let theme = MarkdownTheme.zcode

        #expect(theme.unorderedListTopSpacing == 12)
        #expect(theme.unorderedListBottomSpacing == 12)
        #expect(theme.unorderedListLeadingPadding == 20)
        #expect(theme.listItemSpacing == 6)
        #expect(theme.nestedListTopSpacing == 6)
        #expect(theme.nestedListBottomSpacing == 6)
    }

    @Test("V4 有序列表规格")
    func zcodeOrderedList() {
        let theme = MarkdownTheme.zcode

        #expect(theme.orderedListLeadingPadding == 0)
        #expect(theme.orderedListItemLeadingPadding == 4)
        #expect(theme.orderedListUsesInsideDecimal == true)
    }

    // MARK: - V4 引用

    @Test("V4 引用块规格")
    func zcodeQuote() {
        let theme = MarkdownTheme.zcode

        #expect(theme.quoteTopSpacing == 16)
        #expect(theme.quoteBottomSpacing == 16)
        #expect(theme.quoteBorderWidth == 2)
        #expect(theme.quoteLeadingPadding == 12)
    }

    // MARK: - V4 链接

    @Test("V4 链接规格")
    func zcodeLink() {
        let theme = MarkdownTheme.zcode

        #expect(theme.linkFontSize == 14)
        #expect(theme.linkWeight == .medium)
        #expect(theme.linkHasUnderlineByDefault == false)
        #expect(theme.linkUnderlineOffset == 4)
    }

    // MARK: - V4 行内代码

    @Test("V4 行内代码规格")
    func zcodeInlineCode() {
        let theme = MarkdownTheme.zcode

        #expect(theme.inlineCodeFontSize == 12)
        #expect(theme.inlineCodeCornerRadius == 6)
        #expect(theme.inlineCodeHorizontalMargin == 2)
        #expect(theme.inlineCodeHorizontalPadding == 6)
        #expect(theme.inlineCodeVerticalPadding == 2)
    }

    // MARK: - V4 正文

    @Test("V4 正文行距由字体行高换算，不等于目标行高")
    func zcodeBodyLineSpacing() {
        let theme = MarkdownTheme.zcode

        // 24.5 是目标行高，lineSpacing 是「额外间距」。
        #expect(theme.bodyTargetLineHeight == 24.5)
        #expect(theme.bodyLineSpacing != theme.bodyTargetLineHeight)
        #expect(theme.bodyLineSpacing > 0)
    }

    @Test("V4 主题不改变 standard 的任何字段")
    func zcodeThemeDoesNotMutateStandard() {
        let standardBefore = MarkdownTheme.standard
        let before = (standardBefore.bodyFont, standardBefore.blockSpacing, standardBefore.listItemSpacing)

        _ = MarkdownTheme.zcode

        let standardAfter = MarkdownTheme.standard
        #expect(standardAfter.bodyFont == before.0)
        #expect(standardAfter.blockSpacing == before.1)
        #expect(standardAfter.listItemSpacing == before.2)
    }
}
