import SwiftUI
import Testing
@testable import LumiUI

/// 跨平台判定的语义约束。
///
/// LumiUI 支持 macOS / iOS / visionOS 三个平台。这里锁定的关键不变式是：
/// **visionOS 绝不能被当成 iOS 或 macOS 之外的「第三类」而静默落到错误分支**。
///
/// 最容易出错的点是 Swift 的 `os(visionOS)` **不会**让 `os(iOS)` 为真。
/// 因此所有「移动端 / UIKit 家族」判定都必须显式包含 `os(visionOS)`，
/// 否则 visionOS 会落到 `#else` 的 macOS 分支。
struct LumiPlatformTests {

    // MARK: - 平台身份互斥

    @Test("平台身份互斥且恰好命中一个")
    func exactlyOnePlatformIdentityMatches() {
        let identities = [
            LumiPlatform.isMacOS,
            LumiPlatform.isiOS,
            LumiPlatform.isVisionOS
        ]

        #expect(identities.filter { $0 }.count == 1)
    }

    @Test("桌面语义只属于 macOS")
    func desktopMeansMacOS() {
        #expect(LumiPlatform.isDesktop == LumiPlatform.isMacOS)
    }

    // MARK: - 家族归属

    @Test("UIKit 家族覆盖 iOS 与 visionOS，不含 macOS")
    func uikitFamilyCoversIOSAndVisionOS() {
        #expect(LumiPlatform.isUIKitFamily == !LumiPlatform.isMacOS)
    }

    @Test("visionOS 属于 UIKit 家族")
    func visionOSBelongsToUIKitFamily() {
        #if os(visionOS)
        #expect(LumiPlatform.isUIKitFamily)
        #expect(LumiPlatform.isSpatial)
        #expect(!LumiPlatform.isiOS)
        #expect(!LumiPlatform.isDesktop)
        #else
        #expect(!LumiPlatform.isSpatial)
        #endif
    }

    @Test("iOS 属于 UIKit 家族但不属于空间计算平台")
    func iOSBelongsToUIKitFamilyOnly() {
        #if os(iOS)
        #expect(LumiPlatform.isUIKitFamily)
        #expect(!LumiPlatform.isSpatial)
        #endif
    }

    // MARK: - 能力判定

    @Test("悬停能力覆盖所有带精确指针的平台")
    func hoverSupportMatchesPointerPlatforms() {
        // macOS 与 visionOS 都有指针设备；iOS 没有。
        let expected = LumiPlatform.isMacOS || LumiPlatform.isVisionOS
        #expect(LumiPlatform.supportsHover == expected)
    }

    @Test("窗口外观桥接只存在于 macOS")
    func windowAppearanceBridgeIsMacOSOnly() {
        #expect(LumiPlatform.supportsWindowAppearanceBridge == LumiPlatform.isMacOS)
    }

    // MARK: - 界面风格

    @Test("界面风格的明暗映射自洽")
    func interfaceStyleMapsToColorSchemeConsistently() {
        #expect(LumiInterfaceStyle(isDark: true).isDark)
        #expect(!LumiInterfaceStyle(isDark: false).isDark)
        #expect(LumiInterfaceStyle(isDark: true) == .dark)
        #expect(LumiInterfaceStyle(isDark: false) == .light)
    }
}
