import LumiUI
import SwiftUI

extension MountainTheme {
    public func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        switch colorScheme {
        case .dark:
            return .derived(
                backgroundHex: "12161D",
                surfaceHex: "1C2230",
                textHex: "FFFFFF",
                accentPrimaryHex: "64748B",
                accentSecondaryHex: "94A3B8",
                accentTertiaryHex: "22C55E",
                isDark: true
            )
        default:
            return .derived(
                backgroundHex: "E2E8F0",
                surfaceHex: "CBD5E1",
                textHex: "0F172A",
                accentPrimaryHex: "475569",
                accentSecondaryHex: "64748B",
                accentTertiaryHex: "16A34A",
                isDark: false
            )
        }
    }
}
