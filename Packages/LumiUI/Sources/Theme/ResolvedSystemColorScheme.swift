import AppKit
import SwiftUI

/// 跟随系统主题时，用于解析 `Color.adaptive` 的当前明暗。
public enum ResolvedSystemColorScheme {
    nonisolated(unsafe) public static var current: ColorScheme = .light
}

@MainActor
public enum ThemeWindowAppearanceSync {
    public static func syncAllWindows() {
        let appearance = LumiUIThemeStore.shared.theme.preferredAppKitAppearance
        NSApp?.windows.forEach { window in
            window.appearance = appearance
            window.contentView?.needsDisplay = true
        }
    }
}
