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

    /// 读取当前系统明暗。
    ///
    /// macOS 在亮色外观下不会写入 `AppleInterfaceStyle`；暗色（包括自动外观
    /// 当前处于暗色的时段）会写入 `Dark`。不能回退到 `NSApp.effectiveAppearance`，
    /// 因为 Lumi 会为窗口强制主题外观，从固定暗色主题切回 `.system` 时该值可能
    /// 仍是旧的 DarkAqua，反过来污染系统外观判断。
    @MainActor
    public static func currentSystemColorScheme() -> ColorScheme {
        if let style = globalInterfaceStyle {
            return style.lowercased().contains("dark") ? .dark : .light
        }
        #if canImport(AppKit)
        return .light
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
            // 与 LumiUIThemeRegistry / Color.adaptive 共用同一份已解析状态，避免
            // NSHostingView 与主 SwiftUI 视图在主题切换过程中分别得到不同分支。
            return ResolvedSystemColorScheme.current
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
            // 使用主题注册中心已经解析好的系统明暗，避免颜色在 AppKit/SwiftUI
            // 渲染阶段再次读取窗口 appearance。否则从固定暗色主题切回 `.system`
            // 时，窗口残留的 DarkAqua 会让背景继续取暗色，而其它组件已取亮色。
            self.init(hex: ResolvedSystemColorScheme.current == .dark ? dark : light)
            #elseif canImport(UIKit)
            let lightUIColor = UIColor(hex: light)
            let darkUIColor = UIColor(hex: dark)
            self.init(UIColor { trait in
                trait.userInterfaceStyle == .dark ? darkUIColor : lightUIColor
            })
            #endif
        case .dark:
            self.init(hex: dark)
        case .light:
            self.init(hex: light)
        }
    }

    /// 基于字符串（如人名）生成固定的自适应颜色，同一输入始终映射到同一色板项。
    ///
    /// 色板为「森林墨」风格：以墨翠打头，整体偏自然/泥土色调（青、赭、苔、莓），
    /// 兼顾与品牌主题的协调与头像之间的可辨识度。
    public static func adaptive(from source: String) -> Color {
        let palette: [Color] = [
            Color(hex: "059669"),  // 墨翠（品牌主色）
            Color(hex: "FF6B6B"),  // 珊瑚
            Color(hex: "4ECDC4"),  // 薄荷青
            Color(hex: "FFB347"),  // 橙
            Color(hex: "45B7D1"),  // 湖蓝
            Color(hex: "96CEB4"),  // 苔
            Color(hex: "DDA0DD"),  // 梅
            Color(hex: "F7DC6F"),  // 柠黄
            Color(hex: "0D9488"),  // 松青
            Color(hex: "85C1E9"),  // 天蓝
            Color(hex: "F1948A"),  // 鲑
            Color(hex: "A0522D"),  // 赭棕
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
