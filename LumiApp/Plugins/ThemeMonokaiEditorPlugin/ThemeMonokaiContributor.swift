import Foundation
import CodeEditSourceEditor
import AppKit

/// Monokai 主题配色方案
/// 经典 Sublime Text 暗色主题，以鲜明的黄绿橙红著称
@MainActor
final class ThemeMonokaiContributor: EditorThemeContributor {
    let id: String = "monokai"
    let displayName: String = String(localized: "Monokai", table: "ThemeMonokaiEditor")
    let icon: String? = "flame.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.969, 0.969, 0.890),
            insertionPoint: color(0.969, 0.969, 0.890),
            invisibles: attr(0.380, 0.380, 0.380),
            background: color(0.149, 0.157, 0.133),
            lineHighlight: color(0.200, 0.212, 0.180),
            selection: color(0.380, 0.380, 0.380, 0.5),
            keywords: attr(0.973, 0.282, 0.545),
            commands: attr(0.969, 0.969, 0.890),
            types: attr(0.565, 0.835, 0.259),
            attributes: attr(0.973, 0.282, 0.545),
            variables: attr(0.969, 0.969, 0.890),
            values: attr(0.969, 0.969, 0.890),
            numbers: attr(0.678, 0.624, 0.878),
            strings: attr(0.898, 0.639, 0.310),
            characters: attr(0.898, 0.639, 0.310),
            comments: attr(0.459, 0.447, 0.380)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
