import Foundation
import CodeEditSourceEditor
import AppKit

/// Solarized Light 主题配色方案
@MainActor
final class ThemeSolarizedLightContributor: EditorThemeContributor {
    let id: String = "solarized-light"
    let displayName: String = String(localized: "Solarized Light", table: "ThemeSolarizedLightEditor")
    let icon: String? = "sun.and.horizon.fill"
    let isDark: Bool = false

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.278, 0.294, 0.271),
            insertionPoint: color(0.278, 0.294, 0.271),
            invisibles: attr(0.757, 0.773, 0.753),
            background: color(0.933, 0.910, 0.835),
            lineHighlight: color(0.898, 0.875, 0.800),
            selection: color(0.776, 0.745, 0.663, 0.6),
            keywords: attr(0.298, 0.384, 0.463),
            commands: attr(0.278, 0.294, 0.271),
            types: attr(0.416, 0.337, 0.271),
            attributes: attr(0.463, 0.329, 0.396),
            variables: attr(0.278, 0.294, 0.271),
            values: attr(0.278, 0.294, 0.271),
            numbers: attr(0.529, 0.345, 0.106),
            strings: attr(0.325, 0.388, 0.169),
            characters: attr(0.325, 0.388, 0.169),
            comments: attr(0.612, 0.675, 0.682)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
