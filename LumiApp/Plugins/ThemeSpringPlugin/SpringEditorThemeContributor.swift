import Foundation
import CodeEditSourceEditor
import AppKit

/// Spring 编辑器主题配色方案
/// 春芽绿风格：绿色调 + 桃花粉点缀 + 天空蓝高亮
@MainActor
final class SpringSuperEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "spring"
    let displayName: String = "Spring"
    let icon: String? = "leaf.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.867, 0.906, 0.847),
            insertionPoint: color(0.486, 0.812, 0.478),
            invisibles: attr(0.255, 0.333, 0.282),
            background: color(0.027, 0.067, 0.039),
            lineHighlight: color(0.047, 0.102, 0.063),
            selection: color(0.486, 0.812, 0.478, 0.3),
            keywords: attr(0.082, 0.502, 0.239),
            commands: attr(0.867, 0.906, 0.847),
            types: attr(0.976, 0.659, 0.831),
            attributes: attr(0.145, 0.388, 0.922),
            variables: attr(0.867, 0.906, 0.847),
            values: attr(0.867, 0.906, 0.847),
            numbers: attr(0.976, 0.659, 0.831),
            strings: attr(0.082, 0.502, 0.239),
            characters: attr(0.082, 0.502, 0.239),
            comments: attr(0.412, 0.490, 0.435)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
