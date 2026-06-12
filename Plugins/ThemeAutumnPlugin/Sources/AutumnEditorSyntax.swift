import LumiUI
import SwiftUI

extension AutumnTheme {
    public func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        switch colorScheme {
        case .dark:
            return .derived(
                backgroundHex: "2A1408",
                surfaceHex: "3A1F0F",
                textHex: "FFFFFF",
                accentPrimaryHex: "F97316",
                accentSecondaryHex: "DC2626",
                accentTertiaryHex: "A16207",
                isDark: true
            )
        default:
            return .derived(
                backgroundHex: "FFFFFF",
                surfaceHex: "FFEDD5",
                textHex: "1C1C1E",
                accentPrimaryHex: "EA580C",
                accentSecondaryHex: "B91C1C",
                accentTertiaryHex: "854D0E",
                isDark: false
            )
        }
    }
}
