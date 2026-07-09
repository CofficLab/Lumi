import AppKit
import SwiftUI

/// 跟随系统主题时，用于解析 `Color.adaptive` 的当前明暗。
public enum ResolvedSystemColorScheme {
    nonisolated(unsafe) public static var current: ColorScheme = .light
}

extension NSWindow {
    /// 系统菜单栏 / status item 所在窗口，不应套用 Lumi 主题 `appearance`。
    var isMenuBarOwnedWindow: Bool {
        level == .statusBar
    }
}

/// 将宿主 `NSWindow.appearance` 同步为当前 Lumi 主题。
/// 跳过菜单栏系统窗口，避免污染 status item 的壁纸自适应着色。
@MainActor
public enum ThemeWindowAppearanceSync {
    public static func syncAllWindows() {
        let appearance = LumiUIThemeStore.shared.theme.preferredAppKitAppearance
        NSApp?.windows.forEach { window in
            guard !window.isMenuBarOwnedWindow else { return }
            window.appearance = appearance
            window.contentView?.needsDisplay = true
        }

        NotificationCenter.default.post(name: .lumiThemeDidSyncWindowAppearances, object: nil)
    }

    /// 清除菜单栏系统窗口上被误设的主题外观，恢复壁纸自适应。
    ///
    /// 幂等守卫：仅当当前 `appearance != nil` 时才赋 `nil`，避免重复赋值触发
    /// `effectiveAppearance` KVO 自激振荡（→ MenuBarService.replaceMenuBarContent 死循环）。
    public static func restoreMenuBarSystemAppearance() {
        NSApp?.windows
            .filter(\.isMenuBarOwnedWindow)
            .forEach { window in
                if window.appearance != nil {
                    window.appearance = nil
                    window.contentView?.needsDisplay = true
                }
            }
    }
}

public extension Notification.Name {
    static let lumiThemeDidSyncWindowAppearances = Notification.Name("lumiThemeDidSyncWindowAppearances")
}
