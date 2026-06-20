import AppKit
import SwiftUI

public extension LumiUITheme {
    /// AppKit 窗口/控件应使用的外观，与 ``preferredColorScheme`` 保持一致。
    var preferredAppKitAppearance: NSAppearance? {
        switch preferredColorScheme {
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .light:
            return NSAppearance(named: .aqua)
        @unknown default:
            return nil
        }
    }
}

private struct AppThemedAppearanceModifier: ViewModifier {
    @LumiTheme private var theme

    func body(content: Content) -> some View {
        content.preferredColorScheme(theme.preferredColorScheme)
    }
}

public extension View {
    /// 让 SwiftUI 控件（TextField、Picker 等）使用与当前 Lumi 主题一致的外观。
    func appThemedAppearance() -> some View {
        modifier(AppThemedAppearanceModifier())
    }
}

/// 将宿主 `NSWindow.appearance` 同步为当前 Lumi 主题，修复 AppKit 文本控件在
/// 「系统浅色 + 应用暗色主题」下仍使用深色字的问题。
public struct ThemeWindowAppearanceBridge: NSViewRepresentable {
    @ObservedObject private var themeStore = LumiUIThemeStore.shared

    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = ThemeWindowAppearanceHostView()
        view.applyAppearance(from: themeStore.theme)
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ThemeWindowAppearanceHostView)?.applyAppearance(from: themeStore.theme)
    }
}

private final class ThemeWindowAppearanceHostView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyAppearance(from: LumiUIThemeStore.shared.theme)
    }

    func applyAppearance(from theme: any LumiUITheme) {
        guard let window else { return }
        window.appearance = theme.preferredAppKitAppearance
    }
}
