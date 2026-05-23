import SwiftUI
import MarkdownKit
import CodeEditSourceEditor
import LumiUI

/// Markdown 渲染视图（用于聊天消息）
/// 复用 MarkdownKit 的统一渲染逻辑，适配消息列表的滚动行为
struct MarkdownContent: View {
    @LumiUI.LumiTheme private var uiTheme: any LumiUITheme

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
                case 1: return .appTitle
                case 2: return .appSectionTitle
                case 3: return .appBodyEmphasized
                default: return .appCallout
                }
            },
            bodyFont: .appBody,
            codeFont: .appMonoCaption,
            blockSpacing: 8,
            listItemSpacing: 4,
            codeBlockBackground: uiTheme.textSecondary.opacity(0.06),
            quoteBorderColor: uiTheme.textSecondary.opacity(0.4),
            tableHeaderBackground: uiTheme.textSecondary.opacity(0.1),
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
