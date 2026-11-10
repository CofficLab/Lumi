import SwiftUI

// MARK: - 跨平台判定
//
// LumiUI 同时支持 macOS / iOS / visionOS 三个平台。所有平台差异都应通过
// 本文件暴露的语义化判定来表达，而不是在业务代码里散落 `#if os(...)`。
//
// 关键点：Swift 的 `os(visionOS)` **不会**让 `os(iOS)` 为真。
// visionOS 有 UIKit、没有 AppKit，因此 `canImport(UIKit)` 在 visionOS 上也为真。
// 所以「移动端」语义必须显式写成 `os(iOS) || os(visionOS)`，
// 否则 visionOS 会静默落到 macOS 分支。
//
// 三档语义：
// - 需要「UIKit 家族」语义（iOS + visionOS）时用 `LumiPlatform.isUIKitFamily`；
// - 需要「桌面语义」（macOS）时用 `LumiPlatform.isDesktop`；
// - 需要「空间计算语义」（visionOS）时用 `LumiPlatform.isSpatial`。

// MARK: - LumiPlatform

/// LumiUI 的跨平台判定入口。
///
/// 语义定义：
/// - ``isMacOS``：macOS 平台。
/// - ``isiOS``：iOS 平台（**不含** visionOS）。
/// - ``isVisionOS``：visionOS 平台。
/// - ``isUIKitFamily``：使用 UIKit 的平台家族，即 iOS 与 visionOS。
/// - ``isDesktop``：桌面平台语义，即 macOS。
/// - ``isSpatial``：空间计算平台语义，即 visionOS。
/// - ``supportsHover``：支持指针悬停（`onHover`）的平台。
/// - ``supportsWindowAppearanceBridge``：支持把宿主窗口外观与主题同步的平台，
///   仅 AppKit 家族（macOS）具备 `NSWindow.appearance`。
public enum LumiPlatform {

    // MARK: 平台身份

    /// 当前是否为 macOS。
    public static var isMacOS: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    /// 当前是否为 iOS（不含 visionOS）。
    public static var isiOS: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    /// 当前是否为 visionOS。
    public static var isVisionOS: Bool {
        #if os(visionOS)
        return true
        #else
        return false
        #endif
    }

    // MARK: 平台家族

    /// 当前是否属于 UIKit 家族（iOS 与 visionOS）。
    ///
    /// UIKit 家族共享 `UIImage` / `UIColor` / `UIPasteboard` 等 API，
    /// 也共享「分组列表」式的移动端布局语义。
    public static var isUIKitFamily: Bool {
        #if os(iOS) || os(visionOS)
        return true
        #else
        return false
        #endif
    }

    /// 当前是否为桌面平台（macOS）。
    ///
    /// 桌面语义包含窗口外观同步、`NSSplitView` 等 AppKit 专属能力。
    public static var isDesktop: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    /// 当前是否为空间计算平台（visionOS）。
    public static var isSpatial: Bool {
        #if os(visionOS)
        return true
        #else
        return false
        #endif
    }

    // MARK: 能力判定

    /// 当前平台是否支持指针悬停交互。
    ///
    /// macOS 与 visionOS 都有精确指针设备；visionOS 的间接指针设备同样会
    /// 触发 `onHover`，因此悬停反馈在 visionOS 上是有效的。
    /// iOS 缺少精确指针，悬停反馈没有意义。
    public static var supportsHover: Bool {
        #if os(macOS) || os(visionOS)
        return true
        #else
        return false
        #endif
    }

    /// 当前平台是否支持把宿主窗口外观与 Lumi 主题同步。
    ///
    /// 仅 AppKit（macOS）提供 `NSWindow.appearance`；UIKit 家族通过
    /// SwiftUI 的 `preferredColorScheme` 生效。
    public static var supportsWindowAppearanceBridge: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - LumiInterfaceStyle

/// 跨平台的人机界面风格（浅色 / 深色）。
///
/// 避免在业务代码里直接引用 `NSAppearance` 或 `UITraitCollection`，
/// 使平台差异集中在本文件内。
public enum LumiInterfaceStyle: Sendable {
    case light
    case dark

    /// 直接指定明暗。
    public init(isDark: Bool) {
        self = isDark ? .dark : .light
    }

    /// 是否为深色。
    public var isDark: Bool {
        self == .dark
    }

    /// 对应的 SwiftUI 配色方案。
    @MainActor
    public var colorScheme: ColorScheme {
        isDark ? .dark : .light
    }
}
