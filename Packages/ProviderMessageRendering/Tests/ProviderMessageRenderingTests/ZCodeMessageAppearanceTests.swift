import Foundation
import SwiftUI
import Testing
@testable import ProviderMessageRendering

/// `ZCodeMessageAppearance` 双主题 token 契约测试。
///
/// 基准是 ZCode 3.15.1 的 `theme-zai-light` / `theme-zai-dark`
/// （`packages/ui/src/styles.css`），不是普通 `.dark` fallback。
/// 断言逐项比较 sRGB 分量，alpha 精度 0.001。
@Suite("ZCode 双主题外观 token")
struct ZCodeMessageAppearanceTests {

    private let accuracy = 0.001

    // MARK: - 明亮主题

    @Test("明亮主题的实色 token 与 ZCode theme-zai-light 一致")
    func lightSolidTokensMatchZCode() {
        let palette = ZCodeMessageAppearance.light

        assertColor(
            palette.background,
            red: 0xF8 / 255.0, green: 0xF8 / 255.0, blue: 0xF8 / 255.0, alpha: 1,
            label: "light.background"
        )
        assertColor(
            palette.panel,
            red: 1.0, green: 1.0, blue: 1.0, alpha: 1,
            label: "light.panel"
        )
        assertColor(
            palette.card,
            red: 1.0, green: 1.0, blue: 1.0, alpha: 1,
            label: "light.card"
        )
        assertColor(
            palette.popover,
            red: 1.0, green: 1.0, blue: 1.0, alpha: 1,
            label: "light.popover"
        )
        assertColor(
            palette.foreground,
            red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x26 / 255.0, alpha: 1,
            label: "light.foreground"
        )
        assertColor(
            palette.destructive,
            red: 0xE0 / 255.0, green: 0x31 / 255.0, blue: 0x31 / 255.0, alpha: 1,
            label: "light.destructive"
        )
        assertColor(
            palette.warning,
            red: 0xE0 / 255.0, green: 0x7B / 255.0, blue: 0x00 / 255.0, alpha: 1,
            label: "light.warning"
        )
        assertColor(
            palette.inlineCode,
            red: 0xE6 / 255.0, green: 0xE6 / 255.0, blue: 0xE6 / 255.0, alpha: 1,
            label: "light.inlineCode"
        )
        assertColor(
            palette.iconBlue,
            red: 0x00 / 255.0, green: 0x66 / 255.0, blue: 0xDD / 255.0, alpha: 1,
            label: "light.iconBlue"
        )
    }

    @Test("明亮主题的半透明 token 与 ZCode theme-zai-light 一致")
    func lightTranslucentTokensMatchZCode() {
        let palette = ZCodeMessageAppearance.light

        // rgba(13,13,13,0.10)
        assertColor(
            palette.border,
            red: 13 / 255.0, green: 13 / 255.0, blue: 13 / 255.0, alpha: 0.10,
            label: "light.border"
        )
        // rgba(13,13,13,0.05)
        assertColor(
            palette.hover,
            red: 13 / 255.0, green: 13 / 255.0, blue: 13 / 255.0, alpha: 0.05,
            label: "light.hover"
        )
        // rgba(13,13,13,0.05)
        assertColor(
            palette.selected,
            red: 13 / 255.0, green: 13 / 255.0, blue: 13 / 255.0, alpha: 0.05,
            label: "light.selected"
        )
        // rgba(13,13,13,0.03)
        assertColor(
            palette.surface,
            red: 13 / 255.0, green: 13 / 255.0, blue: 13 / 255.0, alpha: 0.03,
            label: "light.surface"
        )
    }

    // MARK: - 暗色主题

    @Test("暗色主题的实色 token 与 ZCode theme-zai-dark 一致")
    func darkSolidTokensMatchZCode() {
        let palette = ZCodeMessageAppearance.dark

        assertColor(
            palette.background,
            red: 0x16 / 255.0, green: 0x16 / 255.0, blue: 0x16 / 255.0, alpha: 1,
            label: "dark.background"
        )
        assertColor(
            palette.panel,
            red: 0x20 / 255.0, green: 0x20 / 255.0, blue: 0x20 / 255.0, alpha: 1,
            label: "dark.panel"
        )
        assertColor(
            palette.card,
            red: 0x2B / 255.0, green: 0x2B / 255.0, blue: 0x2B / 255.0, alpha: 1,
            label: "dark.card"
        )
        assertColor(
            palette.popover,
            red: 0x2B / 255.0, green: 0x2B / 255.0, blue: 0x2B / 255.0, alpha: 1,
            label: "dark.popover"
        )
        assertColor(
            palette.foreground,
            red: 0xD4 / 255.0, green: 0xD4 / 255.0, blue: 0xD4 / 255.0, alpha: 1,
            label: "dark.foreground"
        )
        assertColor(
            palette.destructive,
            red: 0xFF / 255.0, green: 0x5C / 255.0, blue: 0x5C / 255.0, alpha: 1,
            label: "dark.destructive"
        )
        assertColor(
            palette.warning,
            red: 0xFF / 255.0, green: 0x8A / 255.0, blue: 0x30 / 255.0, alpha: 1,
            label: "dark.warning"
        )
        assertColor(
            palette.inlineCode,
            red: 0x36 / 255.0, green: 0x36 / 255.0, blue: 0x36 / 255.0, alpha: 1,
            label: "dark.inlineCode"
        )
        assertColor(
            palette.iconBlue,
            red: 0x80 / 255.0, green: 0xBE / 255.0, blue: 0xFF / 255.0, alpha: 1,
            label: "dark.iconBlue"
        )
    }

    @Test("暗色主题的半透明 token 与 ZCode theme-zai-dark 一致")
    func darkTranslucentTokensMatchZCode() {
        let palette = ZCodeMessageAppearance.dark

        // rgba(255,255,255,0.10)
        assertColor(
            palette.border,
            red: 1.0, green: 1.0, blue: 1.0, alpha: 0.10,
            label: "dark.border"
        )
        // rgba(255,255,255,0.05)
        assertColor(
            palette.hover,
            red: 1.0, green: 1.0, blue: 1.0, alpha: 0.05,
            label: "dark.hover"
        )
        // rgba(255,255,255,0.10)
        assertColor(
            palette.selected,
            red: 1.0, green: 1.0, blue: 1.0, alpha: 0.10,
            label: "dark.selected"
        )
        // rgba(255,255,255,0.05)
        assertColor(
            palette.surface,
            red: 1.0, green: 1.0, blue: 1.0, alpha: 0.05,
            label: "dark.surface"
        )
    }

    // MARK: - 派生关系

    @Test("subtle 由 foreground 以 60% 派生")
    func subtleIsDerivedFromForegroundAt60Percent() {
        for palette in [ZCodeMessageAppearance.light, ZCodeMessageAppearance.dark] {
            let foreground = palette.foreground
            let subtle = palette.subtle

            // ZCode 用 color-mix(in oklab, foreground 60%, transparent)：
            // 与前景同色，alpha 取 0.6。
            assertColor(
                subtle,
                red: components(foreground).red,
                green: components(foreground).green,
                blue: components(foreground).blue,
                alpha: 0.60,
                label: "subtle alpha"
            )
        }
    }

    @Test("subtlest 在明亮主题取 40%、暗色主题取 30%")
    func subtlestUsesThemeSpecificOpacity() {
        let light = components(ZCodeMessageAppearance.light.subtlest)
        let lightForeground = components(ZCodeMessageAppearance.light.foreground)
        assertColor(
            ZCodeMessageAppearance.light.subtlest,
            red: lightForeground.red,
            green: lightForeground.green,
            blue: lightForeground.blue,
            alpha: 0.40,
            label: "light.subtlest alpha"
        )
        #expect(abs(light.alpha - 0.40) < accuracy)

        let darkForeground = components(ZCodeMessageAppearance.dark.foreground)
        assertColor(
            ZCodeMessageAppearance.dark.subtlest,
            red: darkForeground.red,
            green: darkForeground.green,
            blue: darkForeground.blue,
            alpha: 0.30,
            label: "dark.subtlest alpha"
        )
    }

    @Test("subtle 与 subtlest 是不同层级，不会相等")
    func subtleAndSubtlestDiffer() {
        let light = ZCodeMessageAppearance.light
        let dark = ZCodeMessageAppearance.dark

        #expect(components(light.subtle).alpha != components(light.subtlest).alpha)
        #expect(components(dark.subtle).alpha != components(dark.subtlest).alpha)
    }

    @Test("按外观解析返回对应主题的完整 token 集")
    func paletteResolvesByAppearance() {
        let light = ZCodeMessageAppearance.palette(for: .light)
        let dark = ZCodeMessageAppearance.palette(for: .dark)

        #expect(light == ZCodeMessageAppearance.light)
        #expect(dark == ZCodeMessageAppearance.dark)
    }

    @Test("inline code 的使用态是基础色 50% alpha")
    func inlineCodeOverlayUsesHalfOpacity() {
        // ZCode 的 inline-code 背景为 --color-secondary + 50% alpha，
        // 这里提供基础 token 与半透明叠加色。
        let lightOverlay = ZCodeMessageAppearance.light.inlineCodeOverlay
        assertColor(
            lightOverlay,
            red: 0xE6 / 255.0, green: 0xE6 / 255.0, blue: 0xE6 / 255.0, alpha: 0.5,
            label: "light.inlineCodeOverlay"
        )

        let darkOverlay = ZCodeMessageAppearance.dark.inlineCodeOverlay
        assertColor(
            darkOverlay,
            red: 0x36 / 255.0, green: 0x36 / 255.0, blue: 0x36 / 255.0, alpha: 0.5,
            label: "dark.inlineCodeOverlay"
        )
    }

    // MARK: - 辅助

    private func components(_ color: Color) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        #if canImport(UIKit)
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        NSColor(color).usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return (r, g, b, a)
    }

    private func assertColor(
        _ color: Color,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat,
        label: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let actual = components(color)
        #expect(abs(actual.red - red) < accuracy, "\(label).red", sourceLocation: sourceLocation)
        #expect(abs(actual.green - green) < accuracy, "\(label).green", sourceLocation: sourceLocation)
        #expect(abs(actual.blue - blue) < accuracy, "\(label).blue", sourceLocation: sourceLocation)
        #expect(abs(actual.alpha - alpha) < accuracy, "\(label).alpha", sourceLocation: sourceLocation)
    }
}
