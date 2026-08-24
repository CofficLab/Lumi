import LumiUI
import SwiftUI

extension SpringTheme {
    func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        switch colorScheme {
        case .dark:
            return .derived(
                backgroundHex: "0D1A10",
                surfaceHex: "13251A",
                textHex: "FFFFFF",
                accentPrimaryHex: "7CCF7A",
                accentSecondaryHex: "F9A8D4",
                accentTertiaryHex: "60A5FA",
                isDark: true
            )
        default:
            return .derived(
                backgroundHex: "FFFFFF",
                surfaceHex: "E6F4EA",
                textHex: "1C1C1E",
                accentPrimaryHex: "15803D",
                accentSecondaryHex: "DB2777",
                accentTertiaryHex: "2563EB",
                isDark: false
            )
        }
    }
}
