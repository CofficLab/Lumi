import CoreGraphics
import Foundation
import Testing
@testable import KitMarkdown

/// V5（ChatGPT）表格横向滚动契约测试。
///
/// 基准是 V5 方案第 2.5 节：
/// - 表格不得撑破 768 的阅读列，必须内部横向滚动；
/// - 主题开关 `tableScrollsHorizontally` 是**唯一**开关：
///   为 true 时才包横向 ScrollView，为 false 时保持当前布局。
@Suite("V5 表格横向滚动")
struct ChatGPTTableLayoutTests {

    @Test("V5 主题声明表格横向滚动")
    func chatGPTThemeScrollsHorizontally() {
        #expect(MarkdownTheme.chatGPT.tableScrollsHorizontally == true)
    }

    @Test("V5 的表格列宽有界，不会无限撑宽")
    func chatGPTTableCellWidthIsBounded() {
        let theme = MarkdownTheme.chatGPT

        #expect(theme.tableCellMinWidth == 64)
        #expect(theme.tableCellMaxWidth == 448)
    }

    @Test("V5 的表格圆角与内边距符合设计值")
    func chatGPTTableMetrics() {
        let theme = MarkdownTheme.chatGPT

        #expect(theme.tableCornerRadius == 8)
        #expect(theme.tableBorderWidth == 1)
        #expect(theme.tableCellHorizontalPadding == 10)
        #expect(theme.tableCellVerticalPadding == 6)
        #expect(theme.tableHeaderFontSize == 13)
        #expect(theme.tableHeaderWeight == .semibold)
        #expect(theme.tableHeaderAlignment == .leading)
    }

    @Test("旧主题的表格布局不变")
    func legacyThemeTableLayoutUnchanged() {
        let standard = MarkdownTheme.standard

        // V1–V3 的表格不横向滚动，布局逐值不变。
        #expect(standard.tableScrollsHorizontally == false)
        #expect(standard.tableCornerRadius == 6)
        #expect(standard.tableHeaderFontSize == 12)
        #expect(standard.tableHeaderWeight == .semibold)
        #expect(standard.tableCellHorizontalPadding == 10)
        #expect(standard.tableCellMinWidth == 0)
        #expect(standard.tableCellMaxWidth == 0)
    }

    @Test("V4 的表格布局不变")
    func zcodeThemeTableLayoutUnchanged() {
        let zcode = MarkdownTheme.zcode

        #expect(zcode.tableScrollsHorizontally == true)
        #expect(zcode.tableCornerRadius == 12)
        #expect(zcode.tableCellHorizontalPadding == 12)
        #expect(zcode.tableCellVerticalPadding == 8)
        #expect(zcode.tableHeaderFontSize == 14)
        #expect(zcode.tableHeaderWeight == .regular)
    }

    @Test("V5 的代码块继续内部横滚")
    func chatGPTCodeBlockKeepsInternalScrolling() {
        let theme = MarkdownTheme.chatGPT

        // 代码块不换行，因此宽度由内部滚动处理。
        #expect(theme.codeBlockWrapsLines == false)
        #expect(theme.codeBlockMaxHeight == nil)
    }
}
