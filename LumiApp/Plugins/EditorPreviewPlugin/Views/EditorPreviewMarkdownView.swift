import MarkdownKit
import SwiftUI

/// Markdown file preview view.
struct EditorPreviewMarkdownView: View {
    @EnvironmentObject private var themeVM: ThemeVM

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

    private var currentHighlightProvider: TreeSitterCodeHighlightProvider? {
        guard let contributor = themeVM.currentTheme?.editorThemeContributor
                as? any SuperEditorThemeContributor else {
            return nil
        }
        return TreeSitterCodeHighlightProvider(editorTheme: contributor.createTheme())
    }
}
