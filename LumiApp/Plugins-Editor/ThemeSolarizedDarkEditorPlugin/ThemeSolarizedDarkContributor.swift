import Foundation
import CodeEditSourceEditor
import AppKit

/// Solarized Dark 主题配色方案
@MainActor
final class ThemeSolarizedDarkContributor: EditorThemeContributor {
    let id: String = "solarized-dark"
    let displayName: String = String(localized: "Solarized Dark", table: "ThemeSolarizedDarkEditor")
    let icon: String? = "circle.lefthalf.filled"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.706, 0.725, 0.702),
            insertionPoint: color(0.706, 0.725, 0.702),
            invisibles: attr(0.298, 0.318, 0.310),
            background: color(0.000, 0.169, 0.212),
            lineHighlight: color(0.039, 0.212, 0.259),
            selection: color(0.078, 0.282, 0.341, 0.6),
            keywords: attr(0.451, 0.565, 0.667),
            commands: attr(0.706, 0.725, 0.702),
            types: attr(0.608, 0.490, 0.388),
            attributes: attr(0.667, 0.482, 0.565),
            variables: attr(0.706, 0.725, 0.702),
            values: attr(0.706, 0.725, 0.702),
            numbers: attr(0.878, 0.569, 0.169),
            strings: attr(0.518, 0.600, 0.259),
            characters: attr(0.518, 0.600, 0.259),
            comments: attr(0.380, 0.447, 0.459)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
