import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// 解析 macOS 当前有效外观（不受 SwiftUI `preferredColorScheme` / `NSWindow.appearance` 残留影响）。
@MainActor
public enum SystemAppearanceResolver {
    /// 通过 `UserDefaults` 读取系统级外观偏好，
    /// 不受 `NSWindow.appearance` / `preferredColorScheme` 污染。
    /// `UserDefaults.standard` 是线程安全的，故标记 `nonisolated`。
    nonisolated static var systemIsDarkByPreference: Bool {
        if let style = globalInterfaceStyle {
            return style.lowercased().contains("dark")
        }
        return false
    }

    /// `AppleInterfaceStyle` 存在全局域；`UserDefaults.standard` 在运行时切换时不一定同步。
    nonisolated private static var globalInterfaceStyle: String? {
        UserDefaults.standard.synchronize()
        if let style = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleInterfaceStyle"] as? String,
           !style.isEmpty {
            return style
        }
        if let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle"), !style.isEmpty {
            return style
        }
        return nil
    }

    /// 读取当前系统明暗；优先 UserDefaults，自动模式下回退到 NSApp 有效外观。
    @MainActor
    public static func currentSystemColorScheme() -> ColorScheme {
        if let style = globalInterfaceStyle {
            return style.lowercased().contains("dark") ? .dark : .light
        }
        #if canImport(AppKit)
        guard NSApp != nil else {
            return systemIsDarkByPreference ? .dark : .light
        }
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .dark : .light
        #elseif canImport(UIKit)
        return UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        #endif
    }

    @MainActor
    public static var effectiveColorScheme: ColorScheme {
        currentSystemColorScheme()
    }
}

/// 解析当前 Lumi 应用主题的有效明暗，固定明暗主题不受系统外观影响。
@MainActor
public enum AppThemeAppearanceResolver {
    public static var effectiveColorScheme: ColorScheme {
        switch ActiveChromeTheme.current.appearanceKind {
        case .dark:
            return .dark
        case .light:
            return .light
        case .system:
            return SystemAppearanceResolver.effectiveColorScheme
        }
    }

    /// `Color.adaptive(light:dark:)` 在固定主题下使用的分支。
    #if canImport(AppKit)
    nonisolated static func adaptiveUsesDarkBranch(for appearance: NSAppearance) -> Bool {
        switch ActiveChromeTheme.current.appearanceKind {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            return ResolvedSystemColorScheme.current == .dark
        }
    }
    #endif
}

extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    public static func adaptive(light: String, dark: String) -> Color {
        Color(light: light, dark: dark)
    }

    public init(light: String, dark: String) {
        switch ActiveChromeTheme.current.appearanceKind {
        case .system:
            #if canImport(AppKit)
            // 用 NSColor 动态颜色让 AppKit/SwiftUI 在系统外观切换时自动重新解析，
            // 避免返回静态 Color 导致已渲染视图（如 NSHostingView 承载的文件树 cell）
            // 不随外观刷新、只能靠手动重建视图才更新颜色的问题。
            let lightNSColor = NSColor(hex: light)
            let darkNSColor = NSColor(hex: dark)
            let dynamicNSColor = NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? darkNSColor
                    : lightNSColor
            }
            self.init(dynamicNSColor)
            #elseif canImport(UIKit)
            // iOS：用 UIColor 动态颜色，随 traitCollection.userInterfaceStyle 自动重解析。
            let lightUIColor = UIColor(hex: light)
            let darkUIColor = UIColor(hex: dark)
            let dynamicUIColor = UIColor { trait in
                trait.userInterfaceStyle == .dark ? darkUIColor : lightUIColor
            }
            self.init(dynamicUIColor)
            #endif
        case .dark:
            self.init(hex: dark)
        case .light:
            self.init(hex: light)
        }
    }

    /// 基于字符串（如人名）生成固定的自适应颜色，同一输入始终映射到同一色板项。
    public static func adaptive(from source: String) -> Color {
        let palette: [Color] = [
            Color(hex: "7C6FFF"),
            Color(hex: "FF6B6B"),
            Color(hex: "4ECDC4"),
            Color(hex: "FFB347"),
            Color(hex: "45B7D1"),
            Color(hex: "96CEB4"),
            Color(hex: "DDA0DD"),
            Color(hex: "F7DC6F"),
            Color(hex: "BB8FCE"),
            Color(hex: "85C1E9"),
            Color(hex: "F1948A"),
            Color(hex: "82E0AA"),
        ]

        var hash: UInt64 = 5381
        for byte in source.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        let index = Int(hash % UInt64(palette.count))
        return palette[max(0, index)]
    }

    /// 判断当前颜色在当前外观下是否为浅色（感知亮度 > 0.5）
    ///
    /// 使用平台原生颜色解析后计算相对亮度，支持自适应颜色（adaptive color）。
    public var isLightColor: Bool {
        #if canImport(AppKit)
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return false }
        let r = Double(rgbColor.redComponent)
        let g = Double(rgbColor.greenComponent)
        let b = Double(rgbColor.blueComponent)
        #elseif canImport(UIKit)
        var rf: CGFloat = 0, gf: CGFloat = 0, bf: CGFloat = 0, af: CGFloat = 0
        UIColor(self).getRed(&rf, green: &gf, blue: &bf, alpha: &af)
        let r = Double(rf), g = Double(gf), b = Double(bf)
        #endif
        // ITU-R BT.601 感知亮度公式
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.5
    }
}

#if canImport(AppKit)
private extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
#elseif canImport(UIKit)
private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
#endif
