import Foundation
import CodeEditSourceEditor
import AppKit

/// Dracula 编辑器主题配色方案
/// 灵感来自 Dracula Theme (https://draculatheme.com)
@MainActor
final class DraculaEditorThemeContributor: EditorThemeContributor {
    let id: String = "dracula"
    let displayName: String = "Dracula"
    let icon: String? = "bathtub.fill"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.973, 0.973, 0.949),
            insertionPoint: color(0.973, 0.973, 0.949),
            invisibles: attr(0.384, 0.447, 0.643),
            background: color(0.157, 0.165, 0.212),
            lineHighlight: color(0.267, 0.278, 0.353),
            selection: color(0.267, 0.278, 0.353, 0.6),
            keywords: attr(1.0, 0.475, 0.776),
            commands: attr(0.973, 0.973, 0.949),
            types: attr(0.545, 0.914, 0.992),
            attributes: attr(0.741, 0.576, 0.976),
            variables: attr(0.973, 0.973, 0.949),
            values: attr(0.973, 0.973, 0.949),
            numbers: attr(0.741, 0.576, 0.976),
            strings: attr(0.945, 0.980, 0.549),
            characters: attr(0.945, 0.980, 0.549),
            comments: attr(0.384, 0.447, 0.643)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
