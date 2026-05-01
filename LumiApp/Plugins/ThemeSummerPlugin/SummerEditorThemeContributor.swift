import Foundation
import CodeEditSourceEditor
import AppKit

/// Summer 编辑器主题配色方案
/// 夏日蓝风格：蓝色调 + 活力橙点缀 + 夏日蓝高亮
@MainActor
final class SummerSuperEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "summer"
    let displayName: String = "Summer"
    let icon: String? = "sun.max.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.855, 0.898, 0.953),
            insertionPoint: color(0.239, 0.580, 0.965),
            invisibles: attr(0.227, 0.322, 0.420),
            background: color(0.031, 0.071, 0.122),
            lineHighlight: color(0.051, 0.106, 0.173),
            selection: color(0.239, 0.580, 0.965, 0.3),
            keywords: attr(0.0, 0.373, 0.847),
            commands: attr(0.855, 0.898, 0.953),
            types: attr(0.973, 0.455, 0.090),
            attributes: attr(0.0, 0.373, 0.847),
            variables: attr(0.855, 0.898, 0.953),
            values: attr(0.855, 0.898, 0.953),
            numbers: attr(0.973, 0.455, 0.090),
            strings: attr(0.0, 0.373, 0.847),
            characters: attr(0.0, 0.373, 0.847),
            comments: attr(0.384, 0.463, 0.553)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
