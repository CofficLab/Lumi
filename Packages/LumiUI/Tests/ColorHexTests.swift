import AppKit
import SwiftUI
import Testing
@testable import LumiUI

private struct RGBA: Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.red = nsColor.redComponent
        self.green = nsColor.greenComponent
        self.blue = nsColor.blueComponent
        self.alpha = nsColor.alphaComponent
    }

    func isApproximatelyEqual(to other: RGBA, tolerance: CGFloat = 0.005) -> Bool {
        abs(red - other.red) <= tolerance
            && abs(green - other.green) <= tolerance
            && abs(blue - other.blue) <= tolerance
            && abs(alpha - other.alpha) <= tolerance
    }
}

struct ColorHexTests {
    @Test
    @MainActor
    func sixDigitHexParsesPureRed() {
        let parsed = RGBA(Color(hex: "FF0000"))

        #expect(parsed.isApproximatelyEqual(to: RGBA(red: 1, green: 0, blue: 0)))
    }

    @Test
    @MainActor
    func threeDigitHexExpandsToSixDigitEquivalent() {
        let short = RGBA(Color(hex: "F0A"))
        let long = RGBA(Color(hex: "FF00AA"))

        #expect(short.isApproximatelyEqual(to: long))
    }

    @Test
    @MainActor
    func eightDigitHexAppliesAlphaChannel() {
        let opaque = RGBA(Color(hex: "FF00FF00"))
        let halfAlpha = RGBA(Color(hex: "8000FF00"))

        #expect(opaque.alpha > 0.99)
        #expect(halfAlpha.alpha < opaque.alpha)
        #expect(halfAlpha.alpha > 0.45 && halfAlpha.alpha < 0.55)
    }

    @Test
    @MainActor
    func nonStandardLengthFallsBackToDefaultBranch() {
        // 4-character strings hit the `default` branch, which uses
        // (a, r, g, b) = (1, 1, 1, 0); confirm the result is essentially black with near-zero alpha.
        let parsed = RGBA(Color(hex: "FFFF"))

        #expect(parsed.alpha < 0.01)
    }

    @Test
    @MainActor
    func adaptiveColorDoesNotCrashAndResolvesToOneOfTheVariants() {
        let adaptive = Color.adaptive(light: "FFFFFF", dark: "000000")
        let resolved = NSColor(adaptive).usingColorSpace(.sRGB)

        #expect(resolved != nil)
        let isWhite = (resolved?.redComponent ?? 0) > 0.95 && (resolved?.alphaComponent ?? 0) > 0.95
        let isBlack = (resolved?.redComponent ?? 1) < 0.05 && (resolved?.alphaComponent ?? 0) > 0.95
        #expect(isWhite || isBlack)
    }

    @Test
    @MainActor
    func systemAdaptiveColorIgnoresResidualWindowAppearance() {
        let previousTheme = ActiveChromeTheme.current
        let previousScheme = ResolvedSystemColorScheme.current
        ActiveChromeTheme.current = LumiFallbackChromeTheme()
        defer {
            ActiveChromeTheme.current = previousTheme
            ResolvedSystemColorScheme.current = previousScheme
        }

        ResolvedSystemColorScheme.current = .light
        var lightColor = Color.clear
        NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
            lightColor = Color.adaptive(light: "FFFFFF", dark: "000000")
        }
        #expect(RGBA(lightColor).isApproximatelyEqual(to: RGBA(red: 1, green: 1, blue: 1)))

        ResolvedSystemColorScheme.current = .dark
        var darkColor = Color.clear
        NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance {
            darkColor = Color.adaptive(light: "FFFFFF", dark: "000000")
        }
        #expect(RGBA(darkColor).isApproximatelyEqual(to: RGBA(red: 0, green: 0, blue: 0)))
    }

    @Test
    @MainActor
    func adaptiveColorFollowsFixedDarkThemeRegardlessOfSystemAppearance() {
        struct DarkChrome: LumiAppChromeTheme {
            let identifier = "test-dark"
            let displayName = "Dark"
            let compactName = "Dark"
            let description = "Test"
            let iconName = "moon"
            let iconColor = Color.purple
            let appearanceKind: ThemeAppearanceKind = .dark

            func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
                (.red, .green, .blue)
            }

            func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
                (.black, .gray, .white)
            }

            func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
                (.red, .green, .blue)
            }
        }

        let previous = ActiveChromeTheme.current
        ActiveChromeTheme.current = DarkChrome()
        defer { ActiveChromeTheme.current = previous }

        let adaptive = Color.adaptive(light: "FFFFFF", dark: "050510")
        let resolved = NSColor(adaptive).usingColorSpace(.sRGB)

        #expect(resolved != nil)
        #expect((resolved?.redComponent ?? 1) < 0.05)
        #expect(AppThemeAppearanceResolver.effectiveColorScheme == .dark)
    }

    @Test
    @MainActor
    func appThemeAppearanceResolverIgnoresSystemForFixedLightTheme() {
        struct LightChrome: LumiAppChromeTheme {
            let identifier = "test-light"
            let displayName = "Light"
            let compactName = "Light"
            let description = "Test"
            let iconName = "sun"
            let iconColor = Color.yellow
            let appearanceKind: ThemeAppearanceKind = .light

            func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
                (.red, .green, .blue)
            }

            func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
                (.white, .gray, .black)
            }

            func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
                (.red, .green, .blue)
            }
        }

        let previous = ActiveChromeTheme.current
        ActiveChromeTheme.current = LightChrome()
        defer { ActiveChromeTheme.current = previous }

        #expect(AppThemeAppearanceResolver.effectiveColorScheme == .light)
    }

    @Test
    @MainActor
    func appThemeAppearanceResolverUsesSharedResolvedSchemeForSystemTheme() {
        struct SystemChrome: LumiAppChromeTheme {
            let identifier = "test-system"
            let displayName = "System"
            let compactName = "System"
            let description = "Test"
            let iconName = "circle.lefthalf.filled"
            let iconColor = Color.gray
            let appearanceKind: ThemeAppearanceKind = .system

            func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
                (.red, .green, .blue)
            }

            func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
                (.black, .gray, .white)
            }

            func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
                (.red, .green, .blue)
            }
        }

        let previousTheme = ActiveChromeTheme.current
        let previousScheme = ResolvedSystemColorScheme.current
        ActiveChromeTheme.current = SystemChrome()
        defer {
            ActiveChromeTheme.current = previousTheme
            ResolvedSystemColorScheme.current = previousScheme
        }

        ResolvedSystemColorScheme.current = .dark
        #expect(AppThemeAppearanceResolver.effectiveColorScheme == .dark)

        ResolvedSystemColorScheme.current = .light
        #expect(AppThemeAppearanceResolver.effectiveColorScheme == .light)
    }
}

private extension RGBA {
    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}
