import Foundation
import KitMarkdown
import LumiUI
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// V5（ChatGPT）聊天 Markdown 主题契约测试。
///
/// - Important: 旧 `ChatMarkdownTheme.make(from:)`（V1–V3）与
///   `makeZCode(from:)`（V4）的每个字段必须**逐值不变**；
///   V5 走独立的 `makeChatGPT(from:)`，三个入口互不影响。
@Suite("V5 聊天 Markdown 主题")
struct ChatGPTChatMarkdownThemeTests {

    @Test("旧 make(from:) 的每个字段逐值不变")
    func legacyMakeKeepsEveryField() {
        let theme = TestLumiTheme()
        let markdownTheme = ChatMarkdownTheme.make(from: theme)

        #expect(markdownTheme.headingFont(1) == .system(size: 17, weight: .semibold))
        #expect(markdownTheme.headingFont(2) == .system(size: 16, weight: .semibold))
        #expect(markdownTheme.headingFont(3) == .system(size: 15, weight: .semibold))
        #expect(markdownTheme.headingFont(4) == .system(size: 14, weight: .semibold))

        #expect(markdownTheme.bodyFont == .system(size: 14))
        #expect(markdownTheme.listItemSpacing == 8)
        #expect(markdownTheme.blockSpacing == MarkdownTheme.standard.blockSpacing)

        #expect(markdownTheme.textColor == theme.textPrimary)
        #expect(markdownTheme.secondaryTextColor == theme.textSecondary)
    }

    @Test("旧 make(from:) 不带 V5 的几何覆盖")
    func legacyMakeDoesNotApplyChatGPTGeometry() {
        let markdownTheme = ChatMarkdownTheme.make(from: TestLumiTheme())

        // V5 的列表项间距是 6；旧主题必须仍是 8。
        #expect(markdownTheme.listItemSpacing == 8)
        #expect(markdownTheme.listItemSpacing != MarkdownTheme.chatGPT.listItemSpacing)
        // V1–V3 的表格不横向滚动。
        #expect(markdownTheme.tableScrollsHorizontally == false)
    }

    @Test("makeZCode 不带 V5 的几何覆盖")
    func zcodeMakeDoesNotApplyChatGPTGeometry() {
        let markdownTheme = ChatMarkdownTheme.makeZCode(from: TestLumiTheme())

        // V4 的正文是 14，V5 是 15。
        #expect(markdownTheme.bodyFont == .system(size: 14))
        #expect(markdownTheme.bodyFont != MarkdownTheme.chatGPT.bodyFont)
        // V4 的目标行高 24.5，V5 是 24。
        #expect(markdownTheme.bodyTargetLineHeight == 24.5)
    }

    @Test("makeChatGPT 继承 MarkdownTheme.chatGPT 的全部几何")
    func chatGPTMakeInheritsChatGPTGeometry() {
        let base = MarkdownTheme.chatGPT
        let markdownTheme = ChatMarkdownTheme.makeChatGPT(from: TestLumiTheme())

        #expect(markdownTheme.headingFont(1) == base.headingFont(1))
        #expect(markdownTheme.headingFont(2) == base.headingFont(2))
        #expect(markdownTheme.headingFont(3) == base.headingFont(3))
        #expect(markdownTheme.headingFont(4) == base.headingFont(4))

        #expect(markdownTheme.bodyFont == base.bodyFont)
        #expect(markdownTheme.listItemSpacing == base.listItemSpacing)
        #expect(markdownTheme.bodyTargetLineHeight == base.bodyTargetLineHeight)
        #expect(markdownTheme.bodyLineSpacing == base.bodyLineSpacing)
        #expect(markdownTheme.tableScrollsHorizontally == base.tableScrollsHorizontally)
        #expect(markdownTheme.tableCellMinWidth == base.tableCellMinWidth)
        #expect(markdownTheme.tableCellMaxWidth == base.tableCellMaxWidth)
    }

    @Test("makeChatGPT 叠加宿主文字颜色")
    func chatGPTMakeAppliesHostColors() {
        let theme = TestLumiTheme()
        let markdownTheme = ChatMarkdownTheme.makeChatGPT(from: theme)

        #expect(markdownTheme.textColor == theme.textPrimary)
        #expect(markdownTheme.secondaryTextColor == theme.textSecondary)
    }

    @Test("V5 正文 15、目标行高 24")
    func chatGPTTypography() {
        let base = MarkdownTheme.chatGPT

        #expect(base.bodyFont == .system(size: 15))
        #expect(base.bodyTargetLineHeight == 24)
        // lineSpacing 是「额外间距」，由目标行高减去字体行高得到。
        #expect(base.bodyLineSpacing > 0)
        #expect(base.bodyLineSpacing != base.bodyTargetLineHeight)
    }

    @Test("V5 表格横向滚动，不撑破阅读列")
    func chatGPTTableScrollsHorizontally() {
        #expect(MarkdownTheme.chatGPT.tableScrollsHorizontally == true)
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
