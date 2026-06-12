import LumiUI
import SwiftUI

extension AuroraTheme {
    public func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        .derived(
            backgroundHex: "120A20",
            surfaceHex: "1F1535",
            textHex: "FFFFFF",
            accentPrimaryHex: "A78BFA",
            accentSecondaryHex: "38BDF8",
            accentTertiaryHex: "34D399",
            isDark: true
        )
    }
}
