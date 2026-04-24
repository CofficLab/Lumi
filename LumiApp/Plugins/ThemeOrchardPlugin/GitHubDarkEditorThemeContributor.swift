import Foundation
import CodeEditSourceEditor
import AppKit

/// GitHub Dark 编辑器主题配色方案
/// 灵感来自 GitHub 官方暗色主题
@MainActor
final class GitHubDarkEditorThemeContributor: EditorThemeContributor {
    let id: String = "github-dark"
    let displayName: String = "GitHub Dark"
    let icon: String? = "chevron.left.forwardslash.chevron.right"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.831, 0.878, 0.922),
            insertionPoint: color(0.831, 0.878, 0.922),
            invisibles: attr(0.310, 0.357, 0.408),
            background: color(0.106, 0.110, 0.141),
            lineHighlight: color(0.141, 0.149, 0.180),
            selection: color(0.259, 0.286, 0.349, 0.5),
            keywords: attr(1.0, 0.533, 0.388),
            commands: attr(0.831, 0.878, 0.922),
            types: attr(0.545, 0.773, 0.922),
            attributes: attr(0.655, 0.773, 0.878),
            variables: attr(0.831, 0.878, 0.922),
            values: attr(0.831, 0.878, 0.922),
            numbers: attr(0.631, 0.914, 0.631),
            strings: attr(0.580, 0.878, 0.451),
            characters: attr(0.580, 0.878, 0.451),
            comments: attr(0.376, 0.412, 0.478)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
