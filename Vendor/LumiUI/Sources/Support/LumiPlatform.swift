import SwiftUI

// MARK: - 跨平台图像 / 剪贴板适配
//
// 把 AppKit(`NSImage`/`NSPasteboard`) 与 UIKit(`UIImage`/`UIPasteboard`) 的差异
// 收口到本文件，LumiUI 其余源码只依赖这里的平台无关 API，从而可以同时编译到
// macOS 与 iOS。

#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

#if os(macOS)
/// 跨平台图像类型：macOS 用 `NSImage`。
public typealias LumiPlatformImage = NSImage

public extension Image {
    /// 从跨平台图像构造 SwiftUI `Image`。
    init(lumiImage image: LumiPlatformImage) {
        self.init(nsImage: image)
    }
}
#elseif os(iOS) || os(visionOS)
/// 跨平台图像类型：iOS 用 `UIImage`。
public typealias LumiPlatformImage = UIImage

public extension Image {
    /// 从跨平台图像构造 SwiftUI `Image`。
    init(lumiImage image: LumiPlatformImage) {
        self.init(uiImage: image)
    }
}
#endif

/// 跨平台剪贴板写入。
public enum LumiPasteboard {
    /// 将字符串复制到系统剪贴板。
    public static func copyString(_ string: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #elseif os(iOS) || os(visionOS)
        UIPasteboard.general.string = string
        #endif
    }
}

// MARK: - 跨平台语义色

public extension Color {
    /// 跨平台"控件背景"语义色（macOS=`.controlBackgroundColor`，iOS=`.secondarySystemBackground`）。
    static var lumiControlBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #elseif os(iOS) || os(visionOS)
        return Color(uiColor: .secondarySystemBackground)
        #endif
    }

    /// 跨平台"文本背景"语义色（macOS=`.textBackgroundColor`，iOS=`.systemBackground`）。
    static var lumiTextBackground: Color {
        #if os(macOS)
        return Color(nsColor: .textBackgroundColor)
        #elseif os(iOS) || os(visionOS)
        return Color(uiColor: .systemBackground)
        #endif
    }
}

// MARK: - iOS 分组列表语义色
//
// iOS 的「分组列表」（Settings.app 风格）有一套独立于 macOS 的语义色：
// 页面底色用 `systemGroupedBackground`，分组卡片用 `secondarySystemGroupedBackground`，
// 文字用 `label` / `secondaryLabel`，分隔线用 `separator`。
// 这里收口为跨平台命名：iOS 取系统语义色，macOS 退回到等价的近似色，
// 使同一套设置组件在两端都能编译，并保持一致的层级关系。

public extension Color {
    /// 分组列表页面底色（iOS=`systemGroupedBackground`）。
    static var lumiGroupedBackground: Color {
        #if os(iOS) || os(visionOS)
        return Color(uiColor: .systemGroupedBackground)
        #else
        return Color.lumiControlBackground
        #endif
    }

    /// 分组卡片底色（iOS=`secondarySystemGroupedBackground`）。
    static var lumiGroupedCardBackground: Color {
        #if os(iOS) || os(visionOS)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #else
        return Color.lumiTextBackground
        #endif
    }

    /// 主文字色（iOS=`label`）。
    static var lumiPrimaryLabel: Color {
        #if os(iOS) || os(visionOS)
        return Color(uiColor: .label)
        #else
        return Color.primary
        #endif
    }

    /// 次要文字色（iOS=`secondaryLabel`）。
    static var lumiSecondaryLabel: Color {
        #if os(iOS) || os(visionOS)
        return Color(uiColor: .secondaryLabel)
        #else
        return Color.secondary
        #endif
    }

    /// 三级文字色（iOS=`tertiaryLabel`），用于箭头等弱化元素。
    static var lumiTertiaryLabel: Color {
        #if os(iOS) || os(visionOS)
        return Color(uiColor: .tertiaryLabel)
        #else
        return Color.secondary.opacity(0.6)
        #endif
    }

    /// 分隔线色（iOS=`separator`）。
    static var lumiSeparator: Color {
        #if os(iOS) || os(visionOS)
        return Color(uiColor: .separator)
        #else
        return Color.primary.opacity(0.12)
        #endif
    }

    /// 三级填充色（iOS=`tertiarySystemFill`），用于搜索框等控件底色。
    static var lumiTertiaryFill: Color {
        #if os(iOS) || os(visionOS)
        return Color(uiColor: .tertiarySystemFill)
        #else
        return Color.primary.opacity(0.06)
        #endif
    }
}

public extension LumiPlatformImage {
    /// 从文件 URL 加载图像（macOS=`NSImage(contentsOf:)`，iOS=`UIImage(contentsOfFile:)`）。
    convenience init?(lumiContentsOf url: URL) {
        #if os(macOS)
        self.init(contentsOf: url)
        #elseif os(iOS) || os(visionOS)
        self.init(contentsOfFile: url.path)
        #endif
    }
}

// MARK: - 跨平台颜色分量

/// 颜色的 sRGB 分量（各分量取值 0...1）。
public struct LumiColorComponents: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public extension Color {
    /// 解析为 sRGB 分量。
    ///
    /// macOS 用 `NSColor.usingColorSpace(.sRGB)`，UIKit 家族用 `UIColor.getRed(...)`。
    /// 解析失败（例如动态颜色尚未解析到具体色域）时回退为不透明黑色。
    var lumiSRGBComponents: LumiColorComponents {
        #if os(macOS)
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else {
            return LumiColorComponents(red: 0, green: 0, blue: 0, alpha: 1)
        }
        return LumiColorComponents(
            red: Double(rgb.redComponent),
            green: Double(rgb.greenComponent),
            blue: Double(rgb.blueComponent),
            alpha: Double(rgb.alphaComponent)
        )
        #elseif os(iOS) || os(visionOS)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return LumiColorComponents(
            red: Double(r),
            green: Double(g),
            blue: Double(b),
            alpha: Double(a)
        )
        #endif
    }
}

