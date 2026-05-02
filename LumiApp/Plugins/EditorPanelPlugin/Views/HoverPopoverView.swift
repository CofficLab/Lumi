import SwiftUI

/// 悬浮提示气泡视图
///
/// 当用户将鼠标悬停在编辑器中的标识符（如变量名、函数名、类型名等）上时，
/// 编辑器会通过 LSP 或内置插件（如 Swift 关键字悬浮插件）收集文档信息，
/// 并以此视图展示 Markdown 格式的悬浮文档卡片。
struct HoverPopoverView: View {
    let markdownText: String
    private let style = EditorHoverOverlayStyle.standard

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            MarkdownBlockRenderer(
                markdown: markdownText,
                theme: hoverTheme
            )
        }
        .padding(style.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .stroke(style.borderColor, lineWidth: style.borderWidth)
                )
        )
        .shadow(color: style.shadowColor, radius: style.shadowRadius, x: 0, y: style.shadowYOffset)
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
