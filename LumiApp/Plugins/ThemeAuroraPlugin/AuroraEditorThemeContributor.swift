import Foundation
import CodeEditSourceEditor
import AppKit

/// Aurora 编辑器主题配色方案
/// 极光紫风格：紫色调 + 天空蓝点缀 + 极光绿高亮
@MainActor
final class AuroraSuperEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "aurora"
    let displayName: String = "Aurora"
    let icon: String? = "sparkles"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.886, 0.867, 0.933),
            insertionPoint: color(0.886, 0.867, 0.933),
            invisibles: attr(0.318, 0.286, 0.400),
            background: color(0.039, 0.020, 0.082),
            lineHighlight: color(0.071, 0.039, 0.129),
            selection: color(0.545, 0.361, 0.965, 0.3),
            keywords: attr(0.545, 0.361, 0.965),
            commands: attr(0.886, 0.867, 0.933),
            types: attr(0.055, 0.647, 0.914),
            attributes: attr(0.655, 0.545, 0.980),
            variables: attr(0.886, 0.867, 0.933),
            values: attr(0.886, 0.867, 0.933),
            numbers: attr(0.055, 0.725, 0.506),
            strings: attr(0.063, 0.812, 0.545),
            characters: attr(0.063, 0.812, 0.545),
            comments: attr(0.384, 0.365, 0.490)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
