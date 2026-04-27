import SwiftUI
import CodeEditSourceEditor

/// 主题适配器（Fallback）
/// 仅在插件系统未加载任何主题时提供默认主题。
/// 正常情况下所有主题由主题插件提供。
enum EditorThemeAdapter {

    /// 便捷构造 Attribute
    private static func attr(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> EditorTheme.Attribute {
        EditorTheme.Attribute(color: NSColor(red: r, green: g, blue: b, alpha: a))
    }

    /// 便捷构造 NSColor
    private static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
        NSColor(red: r, green: g, blue: b, alpha: a)
    }

    /// Fallback 主题（Xcode Dark 配色）
    /// 当插件系统未注册任何主题时使用
    @MainActor
    static func fallbackTheme() -> EditorTheme {
        EditorTheme(
            text: attr(1.0, 1.0, 1.0),
            insertionPoint: color(1.0, 1.0, 1.0),
            invisibles: attr(0.4, 0.4, 0.4),
            background: color(0.116, 0.116, 0.137),
            lineHighlight: color(0.204, 0.216, 0.251),
            selection: color(0.298, 0.349, 0.447, 0.6),
            keywords: attr(1.0, 0.149, 0.373),
            commands: attr(0.784, 0.714, 0.541),
            types: attr(0.259, 0.800, 0.835),
            attributes: attr(0.835, 0.596, 0.918),
            variables: attr(1.0, 1.0, 1.0),
            values: attr(0.784, 0.714, 0.541),
            numbers: attr(1.0, 0.388, 0.282),
            strings: attr(1.0, 0.416, 0.337),
            characters: attr(1.0, 0.416, 0.337),
            comments: attr(0.459, 0.498, 0.545)
        )
    }
}
