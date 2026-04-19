import SwiftUI
import MagicKit

/// Markdown 渲染视图（用于聊天消息）
/// 复用 MarkdownKit 的统一渲染逻辑，适配消息列表的滚动行为
struct MarkdownContent: View {
    let content: String

    @Environment(\.preferOuterScroll) private var preferOuterScroll

    var body: some View {
        MarkdownBlockRenderer(
            markdown: content,
            theme: messageTheme
        )
    }

    /// 聊天消息主题
    private var messageTheme: MarkdownTheme {
        MarkdownTheme(
            headingFont: { level in
                switch level {
                case 1: return .system(size: 24, weight: .bold)
                case 2: return .system(size: 20, weight: .semibold)
                case 3: return .system(size: 18, weight: .semibold)
                default: return .system(size: 16, weight: .semibold)
                }
            },
            bodyFont: AppUI.Typography.body,
            codeFont: AppUI.Typography.code,
            blockSpacing: 8,
            listItemSpacing: 4,
            codeBlockBackground: AppUI.Color.semantic.textSecondary.opacity(0.06),
            quoteBorderColor: AppUI.Color.semantic.textSecondary.opacity(0.4),
            tableHeaderBackground: AppUI.Color.semantic.textSecondary.opacity(0.1),
            showLanguageLabel: true
        )
    }
}
