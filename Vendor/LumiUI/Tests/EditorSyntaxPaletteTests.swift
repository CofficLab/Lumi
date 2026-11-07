import SwiftUI
import Testing
@testable import LumiUI

struct EditorSyntaxPaletteTests {
    @Test
    func draculaPresetUsesOfficialBackground() {
        let palette = EditorSyntaxPalette.preset(.dracula)
        #expect(palette.backgroundHex == "282A36")
        #expect(palette.keywords.colorHex == "FF79C6")
    }

    @Test
    func derivedProducesDistinctSyntaxColors() {
        let palette = EditorSyntaxPalette.derived(
            backgroundHex: "1F0A15",
            surfaceHex: "301020",
            textHex: "FFFFFF",
            accentPrimaryHex: "F472B6",
            accentSecondaryHex: "FB7185",
            accentTertiaryHex: "C084FC",
            isDark: true
        )
        #expect(palette.backgroundHex == "1F0A15")
        #expect(palette.strings.colorHex == "FB7185")
    }

    @Test
    @MainActor
    func registryResolvedEditorSyntaxUsesThemePalette() throws {
        struct DraculaChrome: LumiAppChromeTheme {
            let identifier = "dracula"
            let displayName = "Dracula"
            let compactName = "Dracula"
            let description = "Test"
            let iconName = "moon"
            let appearanceKind: ThemeAppearanceKind = .dark

            var iconColor: Color { .purple }

            func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
                (.purple, .pink, .cyan)
            }

            func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
                (.black, .gray, .white)
            }

            func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
                (.purple, .pink, .cyan)
            }

            func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
                .preset(.dracula)
            }
        }

        let registry = LumiUIThemeRegistry()
        try registry.replaceAll([
            LumiUIThemeContribution(
                sortKey: ThemeSortKey(pluginOrder: 1, themeId: "dracula"),
                chromeTheme: DraculaChrome(),
                editorThemeId: "dracula"
            ),
        ])

        let resolved = registry.resolvedEditorSyntax(colorScheme: .dark)
        #expect(resolved?.themeId == "dracula")
        #expect(resolved?.palette.backgroundHex == "282A36")
        #expect(resolved?.isDark == true)
    }

    @Test
    @MainActor
    func derivedFromAdaptiveChromeUsesDarkBranchWhenThemeIsFixedDark() {
        struct AdaptiveDarkChrome: LumiAppChromeTheme {
            let identifier = "adaptive-dark"
            let displayName = "Adaptive Dark"
            let compactName = "Dark"
            let description = "Test"
            let iconName = "moon"
            let iconColor = Color.purple
            let appearanceKind: ThemeAppearanceKind = .dark

            func accentColors() -> (primary: Color, secondary: Color, tertiary: Color) {
                (
                    primary: Color.adaptive(light: "5B4FCF", dark: "5B4FCF"),
                    secondary: Color.adaptive(light: "7C6FFF", dark: "7C6FFF"),
                    tertiary: Color.adaptive(light: "00B4D8", dark: "00D4FF")
                )
            }

            func atmosphereColors() -> (deep: Color, medium: Color, light: Color) {
                (
                    deep: Color.adaptive(light: "F5F5FA", dark: "050510"),
                    medium: Color.adaptive(light: "FFFFFF", dark: "0A0A1F"),
                    light: Color.adaptive(light: "E8E8F2", dark: "151530")
                )
            }

            func glowColors() -> (subtle: Color, medium: Color, intense: Color) {
                (.purple, .pink, .cyan)
            }
        }

        let previous = ActiveChromeTheme.current
        ActiveChromeTheme.current = AdaptiveDarkChrome()
        defer { ActiveChromeTheme.current = previous }

        let palette = EditorSyntaxPalette.derived(from: AdaptiveDarkChrome(), colorScheme: .light)
        #expect(palette.backgroundHex == "0A0A1F")
        #expect(palette.text.colorHex == "FFFFFF")
    }
}
