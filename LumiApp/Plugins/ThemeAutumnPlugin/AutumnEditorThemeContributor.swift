import Foundation
import CodeEditSourceEditor
import AppKit

/// Autumn 编辑器主题配色方案
/// 秋日橙风格：橙色调 + 枫叶红点缀 + 秋叶金高亮
@MainActor
final class AutumnSuperEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "autumn"
    let displayName: String = "Autumn"
    let icon: String? = "leaf"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.906, 0.878, 0.839),
            insertionPoint: color(0.918, 0.545, 0.161),
            invisibles: attr(0.318, 0.278, 0.220),
            background: color(0.082, 0.043, 0.024),
            lineHighlight: color(0.133, 0.067, 0.039),
            selection: color(0.918, 0.545, 0.161, 0.3),
            keywords: attr(0.878, 0.302, 0.047),
            commands: attr(0.906, 0.878, 0.839),
            types: attr(0.851, 0.196, 0.282),
            attributes: attr(0.918, 0.545, 0.161),
            variables: attr(0.906, 0.878, 0.839),
            values: attr(0.906, 0.878, 0.839),
            numbers: attr(0.918, 0.545, 0.161),
            strings: attr(0.851, 0.196, 0.282),
            characters: attr(0.851, 0.196, 0.282),
            comments: attr(0.451, 0.396, 0.333)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
