import SwiftUI
import CodeEditSourceEditor

/// 主题适配器（Fallback）
/// 仅在插件系统未加载任何主题时提供默认主题。
/// 正常情况下所有主题由主题插件提供。
public enum EditorThemeAdapter {
    /// Fallback 主题（Xcode Dark 配色）
    /// 当插件系统未注册任何主题时使用
    @MainActor
    public static func fallbackTheme() -> EditorTheme {
        EditorSyntaxPaletteAdapter.makeEditorTheme(from: .preset(.xcodeDark))
    }

    /// Light syntax theme used for light app themes.
    @MainActor
    public static func lightTheme() -> EditorTheme {
        EditorSyntaxPaletteAdapter.makeEditorTheme(from: .preset(.xcodeLight))
    }
}
