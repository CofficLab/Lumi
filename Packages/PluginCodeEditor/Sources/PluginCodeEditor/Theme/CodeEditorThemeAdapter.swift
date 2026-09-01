import EditorService
import LumiUI
import ProviderTheme
import SwiftUI

/// 将应用主题的语义色板映射为编辑器语法色板。
///
/// `ProviderTheme` 不依赖编辑器模块，因此主题只暴露通用的 accent、atmosphere
/// 和 text 色板。编辑器插件在边界处把这些颜色映射到各个语法捕获类型，保持
/// ProviderTheme 与 EditorService 的依赖方向单向。
@MainActor
enum CodeEditorThemeAdapter {
    static let themeIDPrefix = "com.coffic.lumi.editor.app-theme"

    static func editorThemeID(for theme: ProviderTheme.LumiTheme, colorScheme: ColorScheme) -> String {
        "\(themeIDPrefix).\(theme.id).\(colorScheme == .dark ? "dark" : "light")"
    }

    static func colorScheme(for theme: ProviderTheme.LumiTheme) -> ColorScheme {
        switch theme.appearanceKind {
        case .dark:
            return .dark
        case .light:
            return .light
        case .system:
            return SystemAppearanceResolver.effectiveColorScheme
        }
    }

    static func palettes(for theme: ProviderTheme.LumiTheme) -> [(scheme: ColorScheme, palette: EditorSyntaxPalette)] {
        switch theme.appearanceKind {
        case .dark:
            return [(.dark, makePalette(from: theme, colorScheme: .dark))]
        case .light:
            return [(.light, makePalette(from: theme, colorScheme: .light))]
        case .system:
            return [
                (.dark, makePalette(from: theme, colorScheme: .dark)),
                (.light, makePalette(from: theme, colorScheme: .light)),
            ]
        }
    }

    static func makePalette(
        from theme: ProviderTheme.LumiTheme,
        colorScheme: ColorScheme
    ) -> EditorSyntaxPalette {
        let palette = theme.palette
        let isDark = colorScheme == .dark
        let text = hex(palette.textPrimary, colorScheme: colorScheme)
        let secondaryText = hex(palette.textSecondary, colorScheme: colorScheme)
        let tertiaryText = hex(palette.textTertiary, colorScheme: colorScheme)
        let primary = hex(palette.accentPrimary, colorScheme: colorScheme)
        let secondary = hex(palette.accentSecondary, colorScheme: colorScheme)
        let tertiary = hex(palette.accentTertiary, colorScheme: colorScheme)

        return EditorSyntaxPalette(
            text: .color(text),
            insertionPointHex: text,
            invisibles: .color(tertiaryText),
            backgroundHex: hex(palette.backgroundMedium, colorScheme: colorScheme),
            lineHighlightHex: hex(palette.backgroundLight, colorScheme: colorScheme),
            selectionHex: primary,
            selectionAlpha: isDark ? 0.45 : 0.4,
            keywords: .color(secondary),
            commands: .color(tertiary),
            types: .color(primary),
            attributes: .color(tertiary),
            variables: .color(text),
            values: .color(secondary),
            numbers: .color(primary),
            strings: .color(tertiary),
            characters: .color(tertiary),
            comments: .color(secondaryText)
        )
    }

    private static func hex(_ pair: ThemeHexPair, colorScheme: ColorScheme) -> String {
        colorScheme == .dark ? pair.dark : pair.light
    }
}
