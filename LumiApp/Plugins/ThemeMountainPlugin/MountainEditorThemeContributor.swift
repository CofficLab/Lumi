import Foundation
import CodeEditSourceEditor
import AppKit

/// Mountain 编辑器主题配色方案
/// 山岩灰风格：灰色调 + 冷石青点缀 + 雪山白高亮
@MainActor
final class MountainSuperEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "mountain"
    let displayName: String = "Mountain"
    let icon: String? = "mountain.2.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.831, 0.863, 0.898),
            insertionPoint: color(0.376, 0.651, 0.965),
            invisibles: attr(0.271, 0.306, 0.353),
            background: color(0.063, 0.071, 0.090),
            lineHighlight: color(0.094, 0.102, 0.125),
            selection: color(0.376, 0.651, 0.965, 0.3),
            keywords: attr(0.376, 0.651, 0.965),
            commands: attr(0.831, 0.863, 0.898),
            types: attr(0.549, 0.725, 0.522),
            attributes: attr(0.745, 0.714, 0.667),
            variables: attr(0.831, 0.863, 0.898),
            values: attr(0.831, 0.863, 0.898),
            numbers: attr(0.745, 0.714, 0.667),
            strings: attr(0.549, 0.725, 0.522),
            characters: attr(0.549, 0.725, 0.522),
            comments: attr(0.408, 0.447, 0.506)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
