import LumiUI
import SwiftUI

extension SummerTheme {
    func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        switch colorScheme {
        case .dark:
            return .derived(
                backgroundHex: "082030",
                surfaceHex: "0F2F3F",
                textHex: "FFFFFF",
                accentPrimaryHex: "38BDF8",
                accentSecondaryHex: "FACC15",
                accentTertiaryHex: "34D399",
                isDark: true
            )
        default:
            return .derived(
                backgroundHex: "FFFFFF",
                surfaceHex: "E0F2FE",
                textHex: "102033",
                accentPrimaryHex: "0284C7",
                accentSecondaryHex: "CA8A04",
                accentTertiaryHex: "059669",
                isDark: false
            )
        }
    }
}
