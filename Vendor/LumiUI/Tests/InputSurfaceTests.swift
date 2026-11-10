import SwiftUI
import Testing
@testable import LumiUI

struct InputSurfaceTests {
    @Test
    func innerFieldGeometryMatchesTailwindShadowInner() {
        // tailwind 的 `shadow-inner` 是 `inset 0 2px 4px rgb(0 0 0 / 0.05)`。
        #expect(DesignTokens.Shadow.innerFieldBlur == 2)
        #expect(DesignTokens.Shadow.innerFieldOffsetY == 2)
        #expect(DesignTokens.Shadow.innerFieldInset == 0)

        // 模糊为 0 会让阴影退化成硬边描边；偏移为负会把凹陷感翻到下方。
        #expect(DesignTokens.Shadow.innerFieldBlur > 0)
        #expect(DesignTokens.Shadow.innerFieldOffsetY >= 0)
        #expect(DesignTokens.Shadow.innerFieldInset >= 0)
    }

    @Test
    @MainActor
    func innerFieldOpacityResolvesPerAppearance() {
        let previousTheme = ActiveChromeTheme.current
        let previousScheme = ResolvedSystemColorScheme.current
        ActiveChromeTheme.current = LumiFallbackChromeTheme()
        defer {
            ActiveChromeTheme.current = previousTheme
            ResolvedSystemColorScheme.current = previousScheme
        }

        func opacity(for scheme: ColorScheme) -> Double {
            ResolvedSystemColorScheme.current = scheme
            return DesignTokens.Shadow.innerFieldOpacity
        }

        let lightOpacity = opacity(for: .light)
        let darkOpacity = opacity(for: .dark)

        // 完全透明等于没有阴影；完全不透明会盖住输入内容。
        #expect(lightOpacity > 0.05)
        #expect(darkOpacity > 0.05)
        #expect(lightOpacity < 0.9)
        #expect(darkOpacity < 0.9)

        // 暗色表面与黑色的对比更弱，需要更深的阴影才读得出凹陷。
        #expect(darkOpacity > lightOpacity)
    }
}
