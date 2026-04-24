import Foundation
import CodeEditSourceEditor
import AppKit

/// Winter 编辑器主题配色方案
/// 冬日蓝风格：蓝色调 + 冰雪白点缀 + 霜花青高亮
@MainActor
final class WinterEditorThemeContributor: EditorThemeContributor {
    let id: String = "winter"
    let displayName: String = "Winter"
    let icon: String? = "snowflake"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.867, 0.910, 0.945),
            insertionPoint: color(0.376, 0.651, 0.965),
            invisibles: attr(0.231, 0.322, 0.408),
            background: color(0.031, 0.055, 0.098),
            lineHighlight: color(0.051, 0.082, 0.141),
            selection: color(0.376, 0.651, 0.965, 0.3),
            keywords: attr(0.0, 0.282, 0.667),
            commands: attr(0.867, 0.910, 0.945),
            types: attr(0.549, 0.192, 0.322),
            attributes: attr(0.549, 0.835, 0.871),
            variables: attr(0.867, 0.910, 0.945),
            values: attr(0.867, 0.910, 0.945),
            numbers: attr(0.549, 0.192, 0.322),
            strings: attr(0.0, 0.282, 0.667),
            characters: attr(0.0, 0.282, 0.667),
            comments: attr(0.376, 0.447, 0.541)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
