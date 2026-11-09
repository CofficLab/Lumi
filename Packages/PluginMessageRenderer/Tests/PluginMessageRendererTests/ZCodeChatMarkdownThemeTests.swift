import Foundation
import KitMarkdown
import LumiUI
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// V4（ZCode）聊天 Markdown 主题契约测试。
///
/// - Important: 旧 `ChatMarkdownTheme.make(from:)` 的每个字段必须**逐值不变**；
///   V4 走独立的 `makeZCode(from:)`，两个入口互不影响。
@Suite("ZCode 聊天 Markdown 主题")
struct ZCodeChatMarkdownThemeTests {

    @Test("旧 make(from:) 的每个字段逐值不变")
    func legacyMakeKeepsEveryField() {
        let theme = TestLumiTheme()
        let markdownTheme = ChatMarkdownTheme.make(from: theme)

        // 标题字号与字重。
        #expect(markdownTheme.headingFont(1) == .system(size: 17, weight: .semibold))
        #expect(markdownTheme.headingFont(2) == .system(size: 16, weight: .semibold))
        #expect(markdownTheme.headingFont(3) == .system(size: 15, weight: .semibold))
        #expect(markdownTheme.headingFont(4) == .system(size: 14, weight: .semibold))

        // 字体与间距。
        #expect(markdownTheme.bodyFont == .system(size: 14))
        #expect(markdownTheme.listItemSpacing == 8)
        #expect(markdownTheme.blockSpacing == MarkdownTheme.standard.blockSpacing)

        // 颜色来自宿主。
        #expect(markdownTheme.textColor == theme.textPrimary)
        #expect(markdownTheme.secondaryTextColor == theme.textSecondary)
    }

    @Test("旧 make(from:) 不带 V4 的几何覆盖")
    func legacyMakeDoesNotApplyZCodeGeometry() {
        let markdownTheme = ChatMarkdownTheme.make(from: TestLumiTheme())

        // V4 的列表项间距是 6；旧主题必须仍是 8。
        #expect(markdownTheme.listItemSpacing == 8)
        #expect(markdownTheme.listItemSpacing != MarkdownTheme.zcode.listItemSpacing)
        // V4 的有序列表有 4pt 的条目左 padding；旧主题没有。
        #expect(markdownTheme.orderedListItemLeadingPadding == 0)
    }

    @Test("makeZCode 继承 MarkdownTheme.zcode 的全部几何")
    func zcodeMakeInheritsZCodeGeometry() {
        let base = MarkdownTheme.zcode
        let markdownTheme = ChatMarkdownTheme.makeZCode(from: TestLumiTheme())

        #expect(markdownTheme.headingFont(1) == base.headingFont(1))
        #expect(markdownTheme.headingFont(2) == base.headingFont(2))
        #expect(markdownTheme.headingFont(3) == base.headingFont(3))
        #expect(markdownTheme.headingFont(4) == base.headingFont(4))
        #expect(markdownTheme.headingFont(5) == base.headingFont(5))
        #expect(markdownTheme.headingFont(6) == base.headingFont(6))

        #expect(markdownTheme.bodyFont == base.bodyFont)
        #expect(markdownTheme.listItemSpacing == base.listItemSpacing)
        #expect(markdownTheme.headingTopSpacing == base.headingTopSpacing)
        #expect(markdownTheme.headingBottomSpacing == base.headingBottomSpacing)
        #expect(markdownTheme.unorderedListTopSpacing == base.unorderedListTopSpacing)
        #expect(markdownTheme.unorderedListBottomSpacing == base.unorderedListBottomSpacing)
        #expect(markdownTheme.unorderedListLeadingPadding == base.unorderedListLeadingPadding)
        #expect(markdownTheme.nestedListTopSpacing == base.nestedListTopSpacing)
        #expect(markdownTheme.nestedListBottomSpacing == base.nestedListBottomSpacing)
        #expect(markdownTheme.orderedListLeadingPadding == base.orderedListLeadingPadding)
        #expect(markdownTheme.orderedListItemLeadingPadding == base.orderedListItemLeadingPadding)
        #expect(markdownTheme.orderedListUsesInsideDecimal == base.orderedListUsesInsideDecimal)
        #expect(markdownTheme.quoteTopSpacing == base.quoteTopSpacing)
        #expect(markdownTheme.quoteBottomSpacing == base.quoteBottomSpacing)
        #expect(markdownTheme.quoteBorderWidth == base.quoteBorderWidth)
        #expect(markdownTheme.quoteLeadingPadding == base.quoteLeadingPadding)
        #expect(markdownTheme.linkFontSize == base.linkFontSize)
        #expect(markdownTheme.linkWeight == base.linkWeight)
        #expect(markdownTheme.linkHasUnderlineByDefault == base.linkHasUnderlineByDefault)
        #expect(markdownTheme.linkUnderlineOffset == base.linkUnderlineOffset)
        #expect(markdownTheme.inlineCodeFontSize == base.inlineCodeFontSize)
        #expect(markdownTheme.inlineCodeCornerRadius == base.inlineCodeCornerRadius)
        #expect(markdownTheme.inlineCodeHorizontalMargin == base.inlineCodeHorizontalMargin)
        #expect(markdownTheme.inlineCodeHorizontalPadding == base.inlineCodeHorizontalPadding)
        #expect(markdownTheme.inlineCodeVerticalPadding == base.inlineCodeVerticalPadding)
        #expect(markdownTheme.bodyTargetLineHeight == base.bodyTargetLineHeight)
        #expect(markdownTheme.bodyLineSpacing == base.bodyLineSpacing)
    }

    @Test("makeZCode 叠加宿主文字颜色")
    func zcodeMakeAppliesHostColors() {
        let theme = TestLumiTheme()
        let markdownTheme = ChatMarkdownTheme.makeZCode(from: theme)

        #expect(markdownTheme.textColor == theme.textPrimary)
        #expect(markdownTheme.secondaryTextColor == theme.textSecondary)
    }

    @Test("正文 lineSpacing 由 NSFont 实际行高换算")
    func zcodeBodyLineSpacingDerivedFromFont() {
        let markdownTheme = ChatMarkdownTheme.makeZCode(from: TestLumiTheme())

        #expect(markdownTheme.bodyTargetLineHeight == 24.5)
        #expect(markdownTheme.bodyLineSpacing != markdownTheme.bodyTargetLineHeight)
        #expect(markdownTheme.bodyLineSpacing > 0)
    }
}

/// 最小可用的主题替身。
private struct TestLumiTheme: LumiUITheme {
    let id = "test"
    let name = "Test"

    var primary: Color { .primary }
    var primarySecondary: Color { .secondary }
    var textPrimary: Color { .primary }
    var textSecondary: Color { .secondary }
    var textTertiary: Color { .secondary }
    var textDisabled: Color { .secondary }
    var background: Color { .clear }
    var surface: Color { .clear }
    var elevatedSurface: Color { .clear }
    var overlay: Color { .clear }
    var divider: Color { .clear }
    var success: Color { .green }
    var warning: Color { .orange }
    var error: Color { .red }
    var info: Color { .blue }
}
