import Foundation
import CodeEditSourceEditor
import AppKit

/// River 编辑器主题配色方案
/// 江水蓝风格：青蓝色调 + 水波白点缀 + 江流蓝高亮
@MainActor
final class RiverSuperEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "river"
    let displayName: String = "River"
    let icon: String? = "water.waves"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.851, 0.898, 0.918),
            insertionPoint: color(0.106, 0.812, 0.788),
            invisibles: attr(0.231, 0.318, 0.337),
            background: color(0.039, 0.067, 0.078),
            lineHighlight: color(0.059, 0.102, 0.114),
            selection: color(0.106, 0.812, 0.788, 0.3),
            keywords: attr(0.106, 0.812, 0.788),
            commands: attr(0.851, 0.898, 0.918),
            types: attr(0.376, 0.651, 0.965),
            attributes: attr(0.106, 0.812, 0.788),
            variables: attr(0.851, 0.898, 0.918),
            values: attr(0.851, 0.898, 0.918),
            numbers: attr(0.376, 0.651, 0.965),
            strings: attr(0.106, 0.812, 0.788),
            characters: attr(0.106, 0.812, 0.788),
            comments: attr(0.373, 0.455, 0.478)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
