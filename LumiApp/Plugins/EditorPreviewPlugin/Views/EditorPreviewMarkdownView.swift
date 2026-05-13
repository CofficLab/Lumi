import SwiftUI
import MarkdownKit

/// Markdown 文件预览视图。
///
/// 当编辑器当前文件为 `.md` 时，使用 `MarkdownKit` 的 `MarkdownBlockRenderer`
/// 将 Markdown 源码渲染为 SwiftUI 原生视图，支持标题、段落、列表、代码块、
/// 引用、表格、分隔线、Mermaid 图表等。
struct EditorPreviewMarkdownView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    /// Markdown 源文本
    let markdown: String

    var body: some View {
        ScrollView {
            MarkdownBlockRenderer(
                markdown: markdown,
                theme: previewTheme
            )
            .environment(\.codeHighlightProvider, currentHighlightProvider)
            .padding(24)
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }

    /// 编辑器预览场景的 Markdown 主题
    private var previewTheme: MarkdownTheme {
        let theme = themeVM.activeAppTheme
        return MarkdownTheme(
            headingFont: { level in
                switch level {
                case 1: return .system(size: 26, weight: .bold)
                case 2: return .system(size: 22, weight: .semibold)
                case 3: return .system(size: 18, weight: .semibold)
                default: return .system(size: 16, weight: .semibold)
                }
            },
            bodyFont: .system(size: 15, weight: .regular),
            codeFont: .system(size: 13, weight: .regular, design: .monospaced),
            blockSpacing: 12,
            listItemSpacing: 5,
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
        guard let contributor = themeVM.currentTheme?.editorThemeContributor
                as? any SuperEditorThemeContributor else {
            return nil
        }
        return TreeSitterCodeHighlightProvider(editorTheme: contributor.createTheme())
    }
}
