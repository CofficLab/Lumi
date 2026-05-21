import SwiftUI
import MarkdownKit
import CodeEditSourceEditor

/// Markdown 渲染视图（用于聊天消息）
/// 复用 MarkdownKit 的统一渲染逻辑，适配消息列表的滚动行为
struct MarkdownContent: View {
    let content: String

    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        MarkdownBlockRenderer(
            markdown: content,
            theme: messageTheme
        )
        .environment(\.codeHighlightProvider, currentHighlightProvider)
    }

    /// 聊天消息主题
    private var messageTheme: MarkdownTheme {
        let theme = themeVM.activeChromeTheme
        return MarkdownTheme(
            headingFont: { level in
                switch level {
                case 1: return .system(size: 24, weight: .bold)
                case 2: return .system(size: 20, weight: .semibold)
                case 3: return .system(size: 18, weight: .semibold)
                default: return .system(size: 16, weight: .semibold)
                }
            },
            bodyFont: .system(size: 15, weight: .regular),
            codeFont: .system(size: 13, weight: .regular, design: .monospaced),
            blockSpacing: 8,
            listItemSpacing: 4,
            codeBlockBackground: Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.06),
            quoteBorderColor: Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.4),
            tableHeaderBackground: Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.1),
            showLanguageLabel: true,
            textColor: theme.workspaceTextColor(),
            secondaryTextColor: theme.workspaceSecondaryTextColor()
        )
    }

    /// 当前主题对应的语法高亮提供者
    private var currentHighlightProvider: TreeSitterCodeHighlightProvider? {
        guard let contributor = themeVM.currentTheme?.attachments.editorThemeContributor
                as? any SuperEditorThemeContributor else {
            return nil
        }
        return TreeSitterCodeHighlightProvider(editorTheme: contributor.createTheme())
    }
}
