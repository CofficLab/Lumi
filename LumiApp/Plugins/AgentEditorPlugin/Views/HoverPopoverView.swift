import SwiftUI

/// 悬浮提示气泡视图
struct HoverPopoverView: View {
    let markdownText: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            MarkdownBlockRenderer(
                markdown: markdownText,
                theme: hoverTheme
            )
            .padding(10)
        }
        .frame(maxHeight: 300)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                )
        )
    }

    private var hoverTheme: MarkdownTheme {
        MarkdownTheme(
            headingFont: { level in
                switch level {
                case 1: return .system(size: 14, weight: .bold)
                case 2: return .system(size: 13, weight: .semibold)
                default: return .system(size: 12, weight: .semibold)
                }
            },
            bodyFont: .system(size: 12),
            codeFont: .system(size: 12, design: .monospaced),
            blockSpacing: 6,
            listItemSpacing: 2,
            codeBlockBackground: AppUI.Color.semantic.textSecondary.opacity(0.06),
            quoteBorderColor: AppUI.Color.semantic.textSecondary.opacity(0.4),
            tableHeaderBackground: AppUI.Color.semantic.textSecondary.opacity(0.1),
            showLanguageLabel: true
        )
    }
}
