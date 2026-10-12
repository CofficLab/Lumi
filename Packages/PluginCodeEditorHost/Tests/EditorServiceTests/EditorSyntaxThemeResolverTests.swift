import LumiUI
import SwiftUI
import XCTest
@testable import EditorService

@MainActor
final class EditorSyntaxThemeResolverTests: XCTestCase {
    func testResolveUsesRegisteredContributorPalette() throws {
        let registry = LumiUIThemeRegistry()
        try registry.replaceAll([
            LumiUIThemeContribution(
                sortKey: ThemeSortKey(pluginOrder: 1, themeId: "dracula"),
                chromeTheme: TestChromeTheme(id: "dracula", palette: .preset(.dracula)),
                editorThemeId: "dracula"
            ),
        ])

        let extensions = EditorExtensionRegistry()
        EditorBuiltinSyntaxThemes.registerFallbacks(into: extensions)
        EditorBuiltinSyntaxThemes.registerAppThemes(registry.themes, into: extensions)

        let resolved = EditorSyntaxThemeResolver.resolve(
            registry: registry,
            extensions: extensions,
            colorScheme: .dark
        )

        XCTAssertEqual(resolved.id, "dracula")
        let background = resolved.theme.background.usingColorSpace(.sRGB)
        XCTAssertEqual(background?.redComponent ?? 0, 40.0 / 255.0, accuracy: 0.02)
    }

    func testRegisterOrReplaceThemeContributorOverridesFallback() {
        let extensions = EditorExtensionRegistry()
        EditorBuiltinSyntaxThemes.registerFallbacks(into: extensions)

        let custom = PaletteSyntaxThemeContributor(
            id: "xcode-dark",
            displayName: "Custom",
            isDark: true,
            palette: .preset(.dracula)
        )
        extensions.registerOrReplaceThemeContributor(custom)

        let theme = extensions.theme(for: "xcode-dark")?.createTheme()
        let background = theme?.background.usingColorSpace(.sRGB)
        XCTAssertEqual(background?.redComponent ?? 0, 40.0 / 255.0, accuracy: 0.02)
    }
}

private struct TestChromeTheme: LumiAppChromeTheme {
    let identifier: String
    let displayName: String
    let compactName: String
    let description: String
    let iconName: String
    let appearanceKind: ThemeAppearanceKind = .dark
    let palette: EditorSyntaxPalette

    init(id: String, palette: EditorSyntaxPalette) {
        identifier = id
        displayName = id
        compactName = id
        description = id
        iconName = "circle"
        self.palette = palette
    }

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
        palette
    }
}
