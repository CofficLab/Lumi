import Foundation
import CodeEditSourceEditor
import AppKit

/// High Contrast 编辑器主题配色方案
@MainActor
final class HighContrastEditorThemeContributor: EditorThemeContributor {
    let id: String = "high-contrast"
    let displayName: String = "High Contrast"
    let icon: String? = "circle.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(1.0, 1.0, 1.0),
            insertionPoint: color(1.0, 1.0, 1.0),
            invisibles: attr(0.5, 0.5, 0.5),
            background: color(0.0, 0.0, 0.0),
            lineHighlight: color(0.15, 0.15, 0.15),
            selection: color(0.3, 0.3, 0.5, 0.7),
            keywords: attr(1.0, 0.2, 0.4),
            commands: attr(1.0, 1.0, 1.0),
            types: attr(0.4, 1.0, 0.4),
            attributes: attr(0.9, 0.5, 1.0),
            variables: attr(1.0, 1.0, 1.0),
            values: attr(1.0, 1.0, 1.0),
            numbers: attr(1.0, 0.6, 0.2),
            strings: attr(1.0, 0.9, 0.3),
            characters: attr(1.0, 0.9, 0.3),
            comments: attr(0.6, 0.6, 0.6)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
