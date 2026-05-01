import Foundation
import CodeEditSourceEditor
import AppKit

/// Orchard 编辑器主题配色方案
/// 果园红风格：红色调 + 活力橙点缀 + 青柠绿高亮
@MainActor
final class OrchardSuperEditorThemeContributor: SuperEditorThemeContributor {
    let id: String = "orchard"
    let displayName: String = "Orchard"
    let icon: String? = "apple.logo"
    let isDark: Bool = true

    func createTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.898, 0.855, 0.859),
            insertionPoint: color(0.957, 0.247, 0.369),
            invisibles: attr(0.325, 0.239, 0.251),
            background: color(0.078, 0.027, 0.043),
            lineHighlight: color(0.118, 0.043, 0.063),
            selection: color(0.957, 0.247, 0.369, 0.3),
            keywords: attr(0.882, 0.114, 0.282),
            commands: attr(0.898, 0.855, 0.859),
            types: attr(0.914, 0.455, 0.094),
            attributes: attr(0.522, 0.639, 0.051),
            variables: attr(0.898, 0.855, 0.859),
            values: attr(0.898, 0.855, 0.859),
            numbers: attr(0.914, 0.455, 0.094),
            strings: attr(0.882, 0.114, 0.282),
            characters: attr(0.882, 0.114, 0.282),
            comments: attr(0.471, 0.380, 0.392)
        )
    }

    private func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }
}
