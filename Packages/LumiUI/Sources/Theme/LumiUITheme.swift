import SwiftUI

public protocol LumiUITheme {
    var id: String { get }
    var name: String { get }

    var primary: Color { get }
    var primarySecondary: Color { get }

    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var textDisabled: Color { get }

    var background: Color { get }
    var surface: Color { get }
    var elevatedSurface: Color { get }
    var overlay: Color { get }
    var divider: Color { get }

    var success: Color { get }
    var successGlow: Color { get }
    var warning: Color { get }
    var warningGlow: Color { get }
    var error: Color { get }
    var errorGlow: Color { get }
    var info: Color { get }
    var infoGlow: Color { get }

    var primaryGradient: LinearGradient { get }
    var oceanGradient: LinearGradient { get }
    var auroraGradient: LinearGradient { get }
    var energyGradient: LinearGradient { get }
    var glowBorderGradient: LinearGradient { get }

    var glowAccent: Color { get }

    var statusBarItemForeground: Color { get }
    var statusBarItemBackground: Color { get }
    var statusBarItemPresentedBackground: Color { get }
}

public extension LumiUITheme {
    var successGlow: Color { success.opacity(0.65) }
    var warningGlow: Color { warning.opacity(0.65) }
    var errorGlow: Color { error.opacity(0.65) }
    var infoGlow: Color { info.opacity(0.65) }

    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primarySecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var oceanGradient: LinearGradient {
        LinearGradient(
            colors: [background, elevatedSurface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var auroraGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primarySecondary, info],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var energyGradient: LinearGradient {
        LinearGradient(
            colors: [info, primary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var glowBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.clear,
                divider.opacity(0.55),
                Color.clear,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var glowAccent: Color { primary }

    var statusBarItemForeground: Color { textPrimary }
    var statusBarItemBackground: Color { textPrimary.opacity(0.08) }
    var statusBarItemPresentedBackground: Color { primary.opacity(0.14) }

    /// SwiftUI 控件（如 segmented picker）应使用的外观，避免 popover 与主题背景不一致。
    /// 返回 `nil` 表示不强制，跟随系统外观（适用于 `.system` 主题）。
    var preferredColorScheme: ColorScheme? {
        textPrimary.isLightColor ? .dark : .light
    }
}

/// 启动兜底主题。镜像「森林墨」(`ThemeLumiPlugin.LumiTheme`) 的配色，
/// 让首个视图渲染时即与最终主题一致，避免启动时的明暗/色相闪烁。
/// 真实主题在插件注册后由 ``LumiUIThemeStore`` 替换。
public struct LumiDefaultTheme: LumiUITheme {
    public let id = "lumi-default"
    public let name = "Lumi Default"

    public let primary = Color.adaptive(light: "059669", dark: "34D399")
    public let primarySecondary = Color.adaptive(light: "D97706", dark: "F59E0B")

    public let textPrimary = Color.adaptive(light: "1C1917", dark: "FAFAF9")
    public let textSecondary = Color.adaptive(light: "57534E", dark: "D6D3D1")
    public let textTertiary = Color.adaptive(light: "A8A29E", dark: "A8A29E")
    public let textDisabled = Color.adaptive(light: "BDBDBD", dark: "48484F")

    public let background = Color.adaptive(light: "FAFAF9", dark: "1C1C1A")
    public let surface = Color.adaptive(light: "FFFFFF", dark: "262624")
    public let elevatedSurface = Color.adaptive(light: "E7E5E4", dark: "30302E")
    public let overlay = Color.adaptive(light: "E7E5E4", dark: "383835")
    public let divider = Color.adaptive(light: "E7E5E4", dark: "FFFFFF").opacity(0.15)

    public let success = Color.adaptive(light: "30D158", dark: "30D158")
    public let successGlow = Color.adaptive(light: "7CFFB5", dark: "7CFFB5")
    public let warning = Color.adaptive(light: "FF9F0A", dark: "FF9F0A")
    public let warningGlow = Color.adaptive(light: "FFD57F", dark: "FFD57F")
    public let error = Color.adaptive(light: "FF453A", dark: "FF453A")
    public let errorGlow = Color.adaptive(light: "FF7A73", dark: "FF7A73")
    public let info = Color.adaptive(light: "0EA5E9", dark: "38BDF8")
    public let infoGlow = Color.adaptive(light: "7DD3FC", dark: "7DD3FC")

    public let glowAccent = Color(hex: "10B981")

    public init() {}
}

@MainActor
public final class LumiUIThemeStore: ObservableObject {
    public static let shared = LumiUIThemeStore()

    @Published public private(set) var theme: any LumiUITheme

    private init(theme: any LumiUITheme = LumiDefaultTheme()) {
        self.theme = theme
    }

    public func setTheme(_ theme: any LumiUITheme) {
        // This store is already MainActor-isolated. Publishing through a new
        // unstructured Task lets the first real app view render with the old
        // bootstrap theme, which causes a visible dark-to-light flash at launch.
        self.theme = theme
    }

    /// 系统外观变化时触发依赖 `@LumiTheme` 的视图重绘。
    public func notifyAppearanceRefresh() {
        objectWillChange.send()
    }
}

@MainActor
public func setTheme(_ theme: any LumiUITheme) {
    LumiUIThemeStore.shared.setTheme(theme)
}

@MainActor
public var currentTheme: any LumiUITheme {
    LumiUIThemeStore.shared.theme
}

@propertyWrapper
@MainActor
public struct LumiTheme: DynamicProperty {
    @ObservedObject private var store = LumiUIThemeStore.shared
    @ObservedObject private var registry = LumiUIThemeRegistry.shared

    public init() {}

    public var wrappedValue: any LumiUITheme {
        store.theme
    }
}
