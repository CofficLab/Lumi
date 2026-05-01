import Foundation
import CodeEditSourceEditor
import AppKit

/// Nebula 编辑器主题配色方案
/// 星云粉风格：粉紫色调 + 玫瑰红点缀 + 星云紫高亮
@MainActor
final class NebulaEditorThemeContributor: EditorThemeContributor {
    let id: String = "nebula"
    let displayName: String = "Nebula"
    let icon: String? = "cloud.moon.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.886, 0.855, 0.898),
            insertionPoint: color(0.957, 0.447, 0.714),
            invisibles: attr(0.357, 0.227, 0.325),
            background: color(0.063, 0.020, 0.039),
            lineHighlight: color(0.110, 0.035, 0.071),
            selection: color(0.957, 0.447, 0.714, 0.3),
            keywords: attr(0.855, 0.153, 0.467),
            commands: attr(0.886, 0.855, 0.898),
            types: attr(0.753, 0.518, 0.988),
            attributes: attr(0.878, 0.325, 0.282),
            variables: attr(0.886, 0.855, 0.898),
            values: attr(0.886, 0.855, 0.898),
            numbers: attr(0.753, 0.518, 0.988),
            strings: attr(0.957, 0.447, 0.714),
            characters: attr(0.957, 0.447, 0.714),
            comments: attr(0.475, 0.388, 0.522)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
