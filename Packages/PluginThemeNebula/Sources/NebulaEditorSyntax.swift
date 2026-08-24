import LumiUI
import SwiftUI

extension NebulaTheme {
    public func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        .derived(
            backgroundHex: "1F0A15",
            surfaceHex: "301020",
            textHex: "FFFFFF",
            accentPrimaryHex: "F472B6",
            accentSecondaryHex: "FB7185",
            accentTertiaryHex: "C084FC",
            isDark: true
        )
    }
}
