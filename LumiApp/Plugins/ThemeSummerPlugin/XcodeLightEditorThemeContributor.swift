import Foundation
import CodeEditSourceEditor
import AppKit

/// Xcode Light 编辑器主题配色方案
@MainActor
final class XcodeLightEditorThemeContributor: EditorThemeContributor {
    let id: String = "xcode-light"
    let displayName: String = "Xcode Light"
    let icon: String? = "sun.max.fill"
    let isDark: Bool = false

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.0, 0.0, 0.0),
            insertionPoint: color(0.0, 0.0, 0.0),
            invisibles: attr(0.85, 0.85, 0.85),
            background: color(1.0, 1.0, 1.0),
            lineHighlight: color(0.12, 0.31, 0.51, 0.06),
            selection: color(0.0, 0.478, 1.0, 0.2),
            keywords: attr(0.702, 0.086, 0.149),
            commands: attr(0.0, 0.0, 0.0),
            types: attr(0.247, 0.0, 0.898),
            attributes: attr(0.298, 0.141, 0.482),
            variables: attr(0.0, 0.0, 0.0),
            values: attr(0.0, 0.0, 0.0),
            numbers: attr(0.373, 0.129, 0.0),
            strings: attr(0.463, 0.01, 0.024),
            characters: attr(0.463, 0.01, 0.024),
            comments: attr(0.271, 0.322, 0.298)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
