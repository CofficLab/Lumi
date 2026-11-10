import KitAgentTool
import KernelCore
import LumiLocalizationKit
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import LumiUI
import KitMarkdown
import SwiftUI

enum ChatMarkdownTheme {
    /// V1–V3 的 Markdown 主题。
    ///
    /// - Important: 保留旧签名与旧语义；V1–V3 的呈现**完全不变**。
    static func make(from theme: any LumiUITheme) -> MarkdownTheme {
        MarkdownTheme(
            headingFont: { level in
                switch level {
                case 1: return .system(size: 17, weight: .semibold)
                case 2: return .system(size: 16, weight: .semibold)
                case 3: return .system(size: 15, weight: .semibold)
                default: return .system(size: 14, weight: .semibold)
                }
            },
            bodyFont: .system(size: 14),
            // 列表需要比普通块间距更松,避免连续条目粘成一团。
            listItemSpacing: 8,
            textColor: theme.textPrimary,
            secondaryTextColor: theme.textSecondary
        )
    }

    /// V4（ZCode）的 Markdown 主题。
    ///
    /// 在 `MarkdownTheme.zcode` 的几何基础上叠加宿主的文字颜色。
    ///
    /// - Important: 调用方只能二选一 —— 走 `make(from:)`（V1–V3）
    ///   或走 `makeZCode(from:)`（V4），不允许用同一个入口按 verbosity 分支，
    ///   那样容易让两个版本的呈现互相污染。
    static func makeZCode(from theme: any LumiUITheme) -> MarkdownTheme {
        let base = MarkdownTheme.zcode
        return MarkdownTheme(
            headingFont: base.headingFont,
            bodyFont: base.bodyFont,
            codeFont: base.codeFont,
            blockSpacing: base.blockSpacing,
            listItemSpacing: base.listItemSpacing,
            codeBlockBackground: base.codeBlockBackground,
            quoteBorderColor: base.quoteBorderColor,
            tableHeaderBackground: base.tableHeaderBackground,
            showLanguageLabel: base.showLanguageLabel,
            textColor: theme.textPrimary,
            secondaryTextColor: theme.textSecondary,
            headingTopSpacing: base.headingTopSpacing,
            headingBottomSpacing: base.headingBottomSpacing,
            firstChildRemovesTopSpacing: base.firstChildRemovesTopSpacing,
            unorderedListTopSpacing: base.unorderedListTopSpacing,
            unorderedListBottomSpacing: base.unorderedListBottomSpacing,
            unorderedListLeadingPadding: base.unorderedListLeadingPadding,
            nestedListTopSpacing: base.nestedListTopSpacing,
            nestedListBottomSpacing: base.nestedListBottomSpacing,
            orderedListLeadingPadding: base.orderedListLeadingPadding,
            orderedListItemLeadingPadding: base.orderedListItemLeadingPadding,
            orderedListUsesInsideDecimal: base.orderedListUsesInsideDecimal,
            quoteTopSpacing: base.quoteTopSpacing,
            quoteBottomSpacing: base.quoteBottomSpacing,
            quoteBorderWidth: base.quoteBorderWidth,
            quoteLeadingPadding: base.quoteLeadingPadding,
            linkFontSize: base.linkFontSize,
            linkWeight: base.linkWeight,
            linkHasUnderlineByDefault: base.linkHasUnderlineByDefault,
            linkUnderlineOffset: base.linkUnderlineOffset,
            inlineCodeFontSize: base.inlineCodeFontSize,
            inlineCodeCornerRadius: base.inlineCodeCornerRadius,
            inlineCodeHorizontalMargin: base.inlineCodeHorizontalMargin,
            inlineCodeHorizontalPadding: base.inlineCodeHorizontalPadding,
            inlineCodeVerticalPadding: base.inlineCodeVerticalPadding,
            bodyTargetLineHeight: base.bodyTargetLineHeight,
            bodyLineSpacing: base.bodyLineSpacing,
            codeBlockTopSpacing: base.codeBlockTopSpacing,
            codeBlockBottomSpacing: base.codeBlockBottomSpacing,
            codeBlockCornerRadius: base.codeBlockCornerRadius,
            codeBlockBorderWidth: base.codeBlockBorderWidth,
            codeBlockHeaderLeadingPadding: base.codeBlockHeaderLeadingPadding,
            codeBlockHeaderTrailingPadding: base.codeBlockHeaderTrailingPadding,
            codeBlockHeaderVerticalPadding: base.codeBlockHeaderVerticalPadding,
            codeBlockLanguageFontSize: base.codeBlockLanguageFontSize,
            codeBlockLanguageIsMonospaced: base.codeBlockLanguageIsMonospaced,
            codeBlockLanguageIsLowercase: base.codeBlockLanguageIsLowercase,
            codeBlockLanguageTruncates: base.codeBlockLanguageTruncates,
            codeBlockDefaultLanguage: base.codeBlockDefaultLanguage,
            codeBlockHeaderFileIconSize: base.codeBlockHeaderFileIconSize,
            codeBlockHeaderActionButtonSize: base.codeBlockHeaderActionButtonSize,
            codeBlockHeaderActionIconSize: base.codeBlockHeaderActionIconSize,
            codeBlockContentHorizontalPadding: base.codeBlockContentHorizontalPadding,
            codeBlockContentTopPadding: base.codeBlockContentTopPadding,
            codeBlockContentBottomPadding: base.codeBlockContentBottomPadding,
            codeBlockFontSize: base.codeBlockFontSize,
            codeBlockShowsLineNumbers: base.codeBlockShowsLineNumbers,
            codeBlockWrapsLines: base.codeBlockWrapsLines,
            codeBlockMaxHeight: base.codeBlockMaxHeight,
            codeBlockCopyFeedbackMilliseconds: base.codeBlockCopyFeedbackMilliseconds,
            codeBlockHighlightsWhileStreaming: base.codeBlockHighlightsWhileStreaming,
            tableCornerRadius: base.tableCornerRadius,
            tableBorderWidth: base.tableBorderWidth,
            tableCellHorizontalPadding: base.tableCellHorizontalPadding,
            tableCellVerticalPadding: base.tableCellVerticalPadding,
            tableHeaderFontSize: base.tableHeaderFontSize,
            tableHeaderWeight: base.tableHeaderWeight,
            tableHeaderAlignment: base.tableHeaderAlignment,
            tableCellMinWidth: base.tableCellMinWidth,
            tableCellMaxWidth: base.tableCellMaxWidth,
            tableScrollsHorizontally: base.tableScrollsHorizontally,
            imageMaxWidthFraction: base.imageMaxWidthFraction,
            imageMaxHeight: base.imageMaxHeight,
            imageCornerRadius: base.imageCornerRadius,
            imagesFormGallery: base.imagesFormGallery,
            imageShowsErrorPlaceholder: base.imageShowsErrorPlaceholder
        )
    }
}
