import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import KitMarkdown

/// V4（ZCode）代码块几何契约测试。
///
/// 基准是 ZCode 3.15.1 计划第 2.5 节：
/// - 外壳上下 16、1px border、`card` 背景、圆角 12、裁剪溢出；
/// - Header：左 12、右 8、垂直 8；语言小写 mono，可 truncate；缺省语言 `text`；
///   文件图标 16；操作按钮 28×28、图标 14；
/// - 内容水平 8、上 0、下 12；字号 12，不采用旧 DESIGN 文档里的 14；
/// - 默认无行号；流式默认不高亮，完成后异步高亮；
/// - 默认不 wrap，长行内部横向滚动；允许现有能力切换 wrap；复制反馈 2000ms；
/// - 不发明固定最大高度。
///
/// - Important: 这些差异必须**纳入 theme**，不得全局替换旧值；
///   V1–V3 的旧代码块快照必须保持不变。
@Suite("ZCode 代码块几何")
struct ZCodeCodeBlockLayoutTests {

    // MARK: - 外壳

    @Test("代码块外壳上下间距是 16")
    func shellVerticalSpacingIs16() {
        #expect(MarkdownTheme.zcode.codeBlockTopSpacing == 16)
        #expect(MarkdownTheme.zcode.codeBlockBottomSpacing == 16)
    }

    @Test("代码块圆角是 12")
    func shellCornerRadiusIs12() {
        #expect(MarkdownTheme.zcode.codeBlockCornerRadius == 12)
    }

    @Test("代码块边框是 1px")
    func shellBorderWidthIs1() {
        #expect(MarkdownTheme.zcode.codeBlockBorderWidth == 1)
    }

    // MARK: - Header

    @Test("Header 内边距是左 12、右 8、垂直 8")
    func headerPadding() {
        let theme = MarkdownTheme.zcode

        #expect(theme.codeBlockHeaderLeadingPadding == 12)
        #expect(theme.codeBlockHeaderTrailingPadding == 8)
        #expect(theme.codeBlockHeaderVerticalPadding == 8)
    }

    @Test("语言标签是小写 mono 12，可 truncate")
    func languageLabelStyle() {
        let theme = MarkdownTheme.zcode

        #expect(theme.codeBlockLanguageFontSize == 12)
        #expect(theme.codeBlockLanguageIsMonospaced == true)
        #expect(theme.codeBlockLanguageIsLowercase == true)
        #expect(theme.codeBlockLanguageTruncates == true)
    }

    @Test("缺省语言是 text")
    func defaultLanguageIsText() {
        #expect(MarkdownTheme.zcode.codeBlockDefaultLanguage == "text")
    }

    @Test("Header 文件图标是 16")
    func headerFileIconIs16() {
        #expect(MarkdownTheme.zcode.codeBlockHeaderFileIconSize == 16)
    }

    @Test("Header 操作按钮是 28×28、图标 14")
    func headerActionButtonMetrics() {
        let theme = MarkdownTheme.zcode

        #expect(theme.codeBlockHeaderActionButtonSize == 28)
        #expect(theme.codeBlockHeaderActionIconSize == 14)
    }

    // MARK: - 内容

    @Test("代码内容内边距是水平 8、上 0、下 12")
    func contentPadding() {
        let theme = MarkdownTheme.zcode

        #expect(theme.codeBlockContentHorizontalPadding == 8)
        #expect(theme.codeBlockContentTopPadding == 0)
        #expect(theme.codeBlockContentBottomPadding == 12)
    }

    @Test("代码字号是 12")
    func codeFontSizeIs12() {
        #expect(MarkdownTheme.zcode.codeBlockFontSize == 12)
    }

    @Test("默认没有行号")
    func noLineNumbersByDefault() {
        #expect(MarkdownTheme.zcode.codeBlockShowsLineNumbers == false)
    }

    @Test("默认不换行")
    func noWrapByDefault() {
        #expect(MarkdownTheme.zcode.codeBlockWrapsLines == false)
    }

    @Test("不设置固定最大高度")
    func noFixedMaxHeight() {
        #expect(MarkdownTheme.zcode.codeBlockMaxHeight == nil)
    }

    @Test("复制反馈时长是 2000ms")
    func copyFeedbackIs2000ms() {
        #expect(MarkdownTheme.zcode.codeBlockCopyFeedbackMilliseconds == 2000)
    }

    // MARK: - 流式

    @Test("流式默认不高亮")
    func streamingDoesNotHighlight() {
        #expect(MarkdownTheme.zcode.codeBlockHighlightsWhileStreaming == false)
    }

    // MARK: - 旧主题不变

    @Test("旧主题没有 V4 的代码块覆盖")
    func legacyThemeHasNoZCodeCodeBlockOverrides() {
        let standard = MarkdownTheme.standard

        // V1–V3 的代码块圆角仍是 6，没有 16px 上下间距。
        #expect(standard.codeBlockCornerRadius == 6)
        #expect(standard.codeBlockTopSpacing == 0)
        #expect(standard.codeBlockBottomSpacing == 0)
        #expect(standard.codeBlockFontSize == 13)
        #expect(standard.codeBlockCopyFeedbackMilliseconds == 2000)
    }
}
