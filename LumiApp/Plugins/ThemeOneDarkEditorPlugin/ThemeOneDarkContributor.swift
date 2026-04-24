import Foundation
import CodeEditSourceEditor
import AppKit

/// One Dark Pro 主题配色方案
/// 灵感来自 Atom 编辑器的标志性暗色主题
@MainActor
final class ThemeOneDarkContributor: EditorThemeContributor {
    let id: String = "one-dark"
    let displayName: String = String(localized: "One Dark", table: "ThemeOneDarkEditor")
    let icon: String? = "circle.lefthalf.filled.inverse"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.655, 0.690, 0.757),
            insertionPoint: color(0.655, 0.690, 0.757),
            invisibles: attr(0.310, 0.337, 0.396),
            background: color(0.180, 0.200, 0.247),
            lineHighlight: color(0.220, 0.239, 0.290),
            selection: color(0.310, 0.337, 0.400, 0.5),
            keywords: attr(0.863, 0.475, 0.620),
            commands: attr(0.655, 0.690, 0.757),
            types: attr(0.439, 0.627, 0.816),
            attributes: attr(0.655, 0.690, 0.757),
            variables: attr(0.655, 0.690, 0.757),
            values: attr(0.655, 0.690, 0.757),
            numbers: attr(0.655, 0.690, 0.757),
            strings: attr(0.612, 0.812, 0.412),
            characters: attr(0.612, 0.812, 0.412),
            comments: attr(0.376, 0.412, 0.486)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
