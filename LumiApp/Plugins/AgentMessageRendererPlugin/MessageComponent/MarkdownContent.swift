import SwiftUI
import MagicKit
import MarkdownKit

/// Markdown 渲染视图（用于聊天消息）
/// 复用 MarkdownKit 的统一渲染逻辑，适配消息列表的滚动行为
struct MarkdownContent: View {
    let content: String

    @EnvironmentObject private var themeVM: ThemeVM
    var body: some View {
        MarkdownBlockRenderer(
            markdown: content,
            theme: messageTheme
        )
    }

    /// 聊天消息主题
    private var messageTheme: MarkdownTheme {
        let theme = themeVM.activeAppTheme
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
}
