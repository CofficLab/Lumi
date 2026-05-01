import Foundation
import CodeEditSourceEditor
import AppKit

/// Void 编辑器主题配色方案
/// 虚空深黑风格：黑靛色调 + 虚空紫 + 虚空粉高亮
@MainActor
final class VoidEditorThemeContributor: EditorThemeContributor {
    let id: String = "void"
    let displayName: String = "Void"
    let icon: String? = "circle.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.890, 0.894, 0.941),
            insertionPoint: color(0.388, 0.396, 0.945),
            invisibles: attr(0.251, 0.251, 0.333),
            background: color(0.008, 0.008, 0.020),
            lineHighlight: color(0.031, 0.031, 0.063),
            selection: color(0.388, 0.396, 0.945, 0.3),
            keywords: attr(0.486, 0.227, 0.929),
            commands: attr(0.890, 0.894, 0.941),
            types: attr(0.922, 0.286, 0.596),
            attributes: attr(0.545, 0.361, 0.965),
            variables: attr(0.890, 0.894, 0.941),
            values: attr(0.890, 0.894, 0.941),
            numbers: attr(0.486, 0.227, 0.929),
            strings: attr(0.922, 0.286, 0.596),
            characters: attr(0.922, 0.286, 0.596),
            comments: attr(0.373, 0.365, 0.471)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
