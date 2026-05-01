import SwiftUI

/// 悬浮提示气泡视图
struct HoverPopoverView: View {
    let markdownText: String
    private let style = EditorHoverOverlayStyle.standard

    var body: some View {
        VStack(alignment: .leading, spacing: style.headerSpacing) {
            HStack(spacing: 6) {
                Text("Hover")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(style.labelForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(style.labelBackground)
                    )
                Spacer(minLength: 0)
            }

            ScrollView(.vertical, showsIndicators: false) {
                MarkdownBlockRenderer(
                    markdown: markdownText,
                    theme: hoverTheme
                )
            }
        }
        .padding(style.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [style.backgroundTop, style.backgroundBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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
