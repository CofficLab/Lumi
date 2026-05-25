import AppKit
import CodeEditSourceEditor
import Foundation

/// Sky 深色编辑器配色（系统深色模式）
@MainActor
final class SkyDarkEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "sky-dark"
    let displayName: String = "Sky Dark"
    let icon: String? = "cloud.moon.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.918, 0.965, 1.0),
            insertionPoint: color(0.376, 0.647, 0.980),
            invisibles: attr(0.310, 0.408, 0.522),
            background: color(0.039, 0.078, 0.137),
            lineHighlight: color(0.071, 0.137, 0.231),
            selection: color(0.220, 0.651, 0.914, 0.30),
            keywords: attr(0.988, 0.792, 0.231),
            commands: attr(0.918, 0.965, 1.0),
            types: attr(0.349, 0.827, 0.969),
            attributes: attr(0.576, 0.773, 0.992),
            variables: attr(0.918, 0.965, 1.0),
            values: attr(0.918, 0.965, 1.0),
            numbers: attr(0.180, 0.831, 0.741),
            strings: attr(0.651, 0.839, 1.0),
            characters: attr(0.651, 0.839, 1.0),
            comments: attr(0.510, 0.596, 0.694)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}

/// Sky 浅色编辑器配色（系统浅色模式）
@MainActor
final class SkyLightEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "sky-light"
    let displayName: String = "Sky Light"
    let icon: String? = "cloud.sun.fill"
    let isDark: Bool = false

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.063, 0.125, 0.200),
            insertionPoint: color(0.008, 0.518, 0.780),
            invisibles: attr(0.745, 0.824, 0.886),
            background: color(0.976, 0.992, 1.0),
            lineHighlight: color(0.894, 0.961, 1.0),
            selection: color(0.055, 0.647, 0.914, 0.22),
            keywords: attr(0.855, 0.435, 0.000),
            commands: attr(0.063, 0.125, 0.200),
            types: attr(0.008, 0.518, 0.780),
            attributes: attr(0.220, 0.451, 0.780),
            variables: attr(0.063, 0.125, 0.200),
            values: attr(0.063, 0.125, 0.200),
            numbers: attr(0.047, 0.580, 0.533),
            strings: attr(0.000, 0.451, 0.659),
            characters: attr(0.000, 0.451, 0.659),
            comments: attr(0.408, 0.502, 0.596)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
