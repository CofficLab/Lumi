import AppKit
import SwiftUI

extension EditorSyntaxPalette {
    /// 从外壳主题色推导语法调色板，保证编辑器背景与外壳 atmosphere 一致。
    public static func derived(
        backgroundHex: String,
        surfaceHex: String,
        textHex: String,
        accentPrimaryHex: String,
        accentSecondaryHex: String,
        accentTertiaryHex: String,
        isDark: Bool
    ) -> EditorSyntaxPalette {
        let lineHighlight = surfaceHex
        let selection = accentPrimaryHex
        let comment = isDark ? "6272A4" : "6B7885"
        let invisibles = isDark ? "4B5563" : "B3B3B8"

        return EditorSyntaxPalette(
            text: .color(textHex),
            insertionPointHex: textHex,
            invisibles: .color(invisibles),
            backgroundHex: backgroundHex,
            lineHighlightHex: lineHighlight,
            selectionHex: selection,
            selectionAlpha: isDark ? 0.45 : 0.4,
            keywords: .color(accentSecondaryHex),
            commands: .color(accentTertiaryHex),
            types: .color(accentPrimaryHex),
            attributes: .color(accentTertiaryHex),
            variables: .color(textHex),
            values: .color(accentTertiaryHex),
            numbers: .color(accentPrimaryHex),
            strings: .color(isDark ? accentSecondaryHex : accentPrimaryHex),
            characters: .color(isDark ? accentSecondaryHex : accentPrimaryHex),
            comments: .color(comment)
        )
    }

    /// 使用 `LumiAppChromeTheme` 已声明的 atmosphere / accent 推导语法色。
    public static func derived(from chrome: any LumiAppChromeTheme, colorScheme: ColorScheme) -> EditorSyntaxPalette {
        let atmosphere = chrome.atmosphereColors()
        let accent = chrome.accentColors()
        let isDark = resolvedIsDark(chrome: chrome, colorScheme: colorScheme)

        return derived(
            backgroundHex: hexString(from: atmosphere.medium, isDark: isDark, fallback: isDark ? "1C1C1E" : "FFFFFF"),
            surfaceHex: hexString(from: isDark ? atmosphere.light : atmosphere.deep, isDark: isDark, fallback: isDark ? "2C2C2E" : "F2F2F7"),
            textHex: hexString(from: chrome.workspaceTextColor(), isDark: isDark, fallback: isDark ? "FFFFFF" : "1C1C1E"),
            accentPrimaryHex: hexString(from: accent.primary, isDark: isDark, fallback: "0A84FF"),
            accentSecondaryHex: hexString(from: accent.secondary, isDark: isDark, fallback: "5E5CE6"),
            accentTertiaryHex: hexString(from: accent.tertiary, isDark: isDark, fallback: "30D158"),
            isDark: isDark
        )
    }

    private static func resolvedIsDark(chrome: any LumiAppChromeTheme, colorScheme: ColorScheme) -> Bool {
        switch chrome.appearanceKind {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            return colorScheme == .dark
        }
    }

    private static func hexString(from color: Color, isDark: Bool, fallback: String) -> String {
        let appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)!
        var rgb: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            rgb = NSColor(color).usingColorSpace(.sRGB)
        }
        guard let rgb else { return fallback }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
