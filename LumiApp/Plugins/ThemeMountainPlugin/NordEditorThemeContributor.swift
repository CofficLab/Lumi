import Foundation
import CodeEditSourceEditor
import AppKit

/// Nord 编辑器主题配色方案
/// 灵感来自北极日落的柔和冷色调 (https://www.nordtheme.com)
@MainActor
final class NordEditorThemeContributor: EditorThemeContributor {
    let id: String = "nord"
    let displayName: String = "Nord"
    let icon: String? = "snowflake"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.780, 0.816, 0.886),
            insertionPoint: color(0.780, 0.816, 0.886),
            invisibles: attr(0.318, 0.357, 0.439),
            background: color(0.133, 0.157, 0.204),
            lineHighlight: color(0.180, 0.204, 0.259),
            selection: color(0.275, 0.310, 0.384, 0.5),
            keywords: attr(0.706, 0.545, 0.855),
            commands: attr(0.780, 0.816, 0.886),
            types: attr(0.545, 0.808, 0.922),
            attributes: attr(0.706, 0.545, 0.855),
            variables: attr(0.780, 0.816, 0.886),
            values: attr(0.780, 0.816, 0.886),
            numbers: attr(0.878, 0.776, 0.424),
            strings: attr(0.698, 0.875, 0.545),
            characters: attr(0.698, 0.875, 0.545),
            comments: attr(0.365, 0.416, 0.525)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
