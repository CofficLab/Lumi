import LumiUI
import SwiftUI

extension RiverTheme {
    func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        switch colorScheme {
        case .dark:
            return .derived(
                backgroundHex: "0A1E2B",
                surfaceHex: "0F2A3A",
                textHex: "FFFFFF",
                accentPrimaryHex: "0EA5E9",
                accentSecondaryHex: "22D3EE",
                accentTertiaryHex: "10B981",
                isDark: true
            )
        default:
            return .derived(
                backgroundHex: "E0F2FE",
                surfaceHex: "BAE6FD",
                textHex: "0F172A",
                accentPrimaryHex: "0284C7",
                accentSecondaryHex: "0891B2",
                accentTertiaryHex: "059669",
                isDark: false
            )
        }
    }
}
