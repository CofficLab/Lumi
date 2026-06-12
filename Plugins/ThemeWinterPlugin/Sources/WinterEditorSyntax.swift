import LumiUI
import SwiftUI

extension WinterTheme {
    func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        switch colorScheme {
        case .dark:
            return .derived(
                backgroundHex: "0D1424",
                surfaceHex: "16203A",
                textHex: "FFFFFF",
                accentPrimaryHex: "60A5FA",
                accentSecondaryHex: "E0F2FE",
                accentTertiaryHex: "A5B4FC",
                isDark: true
            )
        default:
            return .derived(
                backgroundHex: "FFFFFF",
                surfaceHex: "F1F5F9",
                textHex: "0F172A",
                accentPrimaryHex: "2563EB",
                accentSecondaryHex: "93C5FD",
                accentTertiaryHex: "6366F1",
                isDark: false
            )
        }
    }
}
