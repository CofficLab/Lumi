import SwiftUI

/// 将 ``LumiAppChromeTheme`` 映射为组件库使用的 ``LumiUITheme``。
public struct ChromeToUIThemeAdapter: LumiUITheme {
    private let chrome: any LumiAppChromeTheme

    public init(chrome: any LumiAppChromeTheme) {
        self.chrome = chrome
    }

    public var id: String { chrome.identifier }
    public var name: String { chrome.displayName }

    public var primary: Color { chrome.accentColors().primary }
    public var primarySecondary: Color { chrome.accentColors().secondary }

    public var textPrimary: Color { chrome.workspaceTextColor() }
    public var textSecondary: Color { chrome.workspaceSecondaryTextColor() }
    public var textTertiary: Color { chrome.workspaceTertiaryTextColor() }
    public var textDisabled: Color { chrome.workspaceTertiaryTextColor().opacity(0.7) }

    public var background: Color { chrome.atmosphereColors().deep }
    public var surface: Color { chrome.atmosphereColors().medium }
    public var elevatedSurface: Color { chrome.atmosphereColors().light }
    public var overlay: Color { chrome.atmosphereColors().medium.opacity(0.85) }
    public var divider: Color { chrome.statusBarDividerColor() }

    public var success: Color { Color.adaptive(light: "30D158", dark: "30D158") }
    public var warning: Color { Color.adaptive(light: "FF9F0A", dark: "FF9F0A") }
    public var error: Color { Color.adaptive(light: "FF453A", dark: "FF453A") }
    public var info: Color { chrome.accentColors().tertiary }

    public var glowAccent: Color { chrome.accentColors().primary }

    public var statusBarItemForeground: Color {
        chrome.statusBarItemForegroundColor()
    }

    public var statusBarItemBackground: Color {
        chrome.statusBarItemBackgroundColor(isPresented: false)
    }

    public var statusBarItemPresentedBackground: Color {
        chrome.statusBarItemBackgroundColor(isPresented: true)
    }

    /// 跟随系统外观的主题不应强制 `preferredColorScheme`，
    /// 否则从固定亮/暗切回 `.system` 时，之前强制的 appearance 残留会导致
    /// 系统无法正确接管外观。
    @MainActor
    public var preferredColorScheme: ColorScheme? {
        switch chrome.appearanceKind {
        case .system:
            return nil
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }
}
