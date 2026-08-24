import LumiUI
import SwiftUI

extension MidnightTheme {
    public func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        .derived(
            backgroundHex: "0A0A1F",
            surfaceHex: "151530",
            textHex: "FFFFFF",
            accentPrimaryHex: "5B4FCF",
            accentSecondaryHex: "7C6FFF",
            accentTertiaryHex: "00D4FF",
            isDark: true
        )
    }
}
