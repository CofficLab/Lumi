import SwiftUI
import CodeEditSourceEditor

/// 主题适配器（Fallback）
/// 仅在插件系统未加载任何主题时提供默认主题。
/// 正常情况下所有主题由主题插件提供。
public enum EditorThemeAdapter {

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
    public static func fallbackTheme() -> EditorTheme {
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

    /// Light syntax theme used for light app themes.
    @MainActor
    public static func lightTheme() -> EditorTheme {
        EditorTheme(
            text: attr(0.11, 0.11, 0.12),
            insertionPoint: color(0.11, 0.11, 0.12),
            invisibles: attr(0.7, 0.7, 0.72),
            background: color(0.98, 0.98, 0.99),
            lineHighlight: color(0.94, 0.95, 0.97),
            selection: color(0.72, 0.82, 0.98, 0.55),
            keywords: attr(0.78, 0.08, 0.52),
            commands: attr(0.55, 0.39, 0.0),
            types: attr(0.13, 0.45, 0.72),
            attributes: attr(0.55, 0.27, 0.68),
            variables: attr(0.11, 0.11, 0.12),
            values: attr(0.55, 0.39, 0.0),
            numbers: attr(0.11, 0.45, 0.85),
            strings: attr(0.77, 0.10, 0.09),
            characters: attr(0.77, 0.10, 0.09),
            comments: attr(0.42, 0.47, 0.52)
        )
    }
}
