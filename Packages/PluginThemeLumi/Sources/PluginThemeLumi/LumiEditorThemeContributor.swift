import AppKit
import CodeEditSourceEditor
import Foundation
import EditorService

/// Lumi 深色编辑器配色（系统深色模式）
@MainActor
final class LumiDarkEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "lumi-dark"
    let displayName: String = "Lumi Dark"
    let icon: String? = "circle.hexagonpath.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.922, 0.922, 0.961),
            insertionPoint: color(0.039, 0.518, 1.0),
            invisibles: attr(0.373, 0.373, 0.412),
            background: color(0.110, 0.110, 0.118),
            lineHighlight: color(0.173, 0.173, 0.180),
            selection: color(0.220, 0.549, 0.996, 0.28),
            keywords: attr(0.976, 0.376, 0.486),
            commands: attr(0.922, 0.922, 0.961),
            types: attr(0.494, 0.906, 0.529),
            attributes: attr(0.824, 0.659, 1.0),
            variables: attr(0.922, 0.922, 0.961),
            values: attr(0.922, 0.922, 0.961),
            numbers: attr(0.475, 0.753, 1.0),
            strings: attr(1.0, 0.776, 0.459),
            characters: attr(1.0, 0.776, 0.459),
            comments: attr(0.545, 0.580, 0.620)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}

/// Lumi 浅色编辑器配色（系统浅色模式）
@MainActor
final class LumiLightEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "lumi-light"
    let displayName: String = "Lumi Light"
    let icon: String? = "circle.hexagonpath.fill"
    let isDark: Bool = false

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.110, 0.110, 0.118),
            insertionPoint: color(0.0, 0.478, 1.0),
            invisibles: attr(0.780, 0.780, 0.800),
            background: color(1.0, 1.0, 1.0),
            lineHighlight: color(0.949, 0.949, 0.969),
            selection: color(0.0, 0.478, 1.0, 0.22),
            keywords: attr(0.796, 0.188, 0.302),
            commands: attr(0.110, 0.110, 0.118),
            types: attr(0.118, 0.451, 0.647),
            attributes: attr(0.514, 0.322, 0.675),
            variables: attr(0.110, 0.110, 0.118),
            values: attr(0.110, 0.110, 0.118),
            numbers: attr(0.118, 0.451, 0.647),
            strings: attr(0.796, 0.188, 0.302),
            characters: attr(0.796, 0.188, 0.302),
            comments: attr(0.420, 0.447, 0.502)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
