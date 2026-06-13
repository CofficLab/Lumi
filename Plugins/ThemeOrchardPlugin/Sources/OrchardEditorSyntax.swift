import LumiUI
import SwiftUI

extension OrchardTheme {
    func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        switch colorScheme {
        case .dark:
            return .derived(
                backgroundHex: "1F0D12",
                surfaceHex: "2B1118",
                textHex: "FFFFFF",
                accentPrimaryHex: "F43F5E",
                accentSecondaryHex: "F97316",
                accentTertiaryHex: "84CC16",
                isDark: true
            )
        default:
            return .derived(
                backgroundHex: "FFFFFF",
                surfaceHex: "FFE4E6",
                textHex: "1C1C1E",
                accentPrimaryHex: "E11D48",
                accentSecondaryHex: "EA580C",
                accentTertiaryHex: "65A30D",
                isDark: false
            )
        }
    }
}
