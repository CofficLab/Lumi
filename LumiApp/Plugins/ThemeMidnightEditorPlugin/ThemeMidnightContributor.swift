import Foundation
import CodeEditSourceEditor
import AppKit

/// Midnight 主题配色方案
@MainActor
final class ThemeMidnightContributor: EditorThemeContributor {
    let id: String = "midnight"
    let displayName: String = String(localized: "Midnight", table: "ThemeMidnightEditor")
    let icon: String? = "moon.stars.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.933, 0.933, 0.933),
            insertionPoint: color(0.933, 0.933, 0.933),
            invisibles: attr(0.35, 0.35, 0.35),
            background: color(0.059, 0.059, 0.098),
            lineHighlight: color(0.098, 0.098, 0.157),
            selection: color(0.216, 0.275, 0.392, 0.6),
            keywords: attr(0.624, 0.510, 0.878),
            commands: attr(0.933, 0.933, 0.933),
            types: attr(0.282, 0.769, 0.804),
            attributes: attr(0.867, 0.624, 0.867),
            variables: attr(0.933, 0.933, 0.933),
            values: attr(0.933, 0.933, 0.933),
            numbers: attr(0.867, 0.624, 0.271),
            strings: attr(0.600, 0.800, 0.600),
            characters: attr(0.600, 0.800, 0.600),
            comments: attr(0.400, 0.451, 0.518)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
