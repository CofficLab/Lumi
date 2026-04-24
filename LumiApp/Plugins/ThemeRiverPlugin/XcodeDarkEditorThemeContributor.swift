import Foundation
import CodeEditSourceEditor
import AppKit

/// Xcode Dark 编辑器主题配色方案
@MainActor
final class XcodeDarkEditorThemeContributor: EditorThemeContributor {
    let id: String = "xcode-dark"
    let displayName: String = "Xcode Dark"
    let icon: String? = "moon.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(1.0, 1.0, 1.0),
            insertionPoint: color(1.0, 1.0, 1.0),
            invisibles: attr(0.4, 0.4, 0.4),
            background: color(0.116, 0.116, 0.137),
            lineHighlight: color(0.204, 0.216, 0.251),
            selection: color(0.298, 0.349, 0.447, 0.6),
            keywords: attr(1.0, 0.149, 0.373),
            commands: attr(0.784, 0.714, 0.541),
            types: attr(0.259, 0.800, 0.835),
            attributes: attr(0.835, 0.596, 0.918),
            variables: attr(1.0, 1.0, 1.0),
            values: attr(0.784, 0.714, 0.541),
            numbers: attr(1.0, 0.388, 0.282),
            strings: attr(1.0, 0.416, 0.337),
            characters: attr(1.0, 0.416, 0.337),
            comments: attr(0.459, 0.498, 0.545)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
