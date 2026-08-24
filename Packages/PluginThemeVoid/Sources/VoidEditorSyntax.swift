import LumiUI
import SwiftUI

extension VoidTheme {
    func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        .derived(
            backgroundHex: "080810",
            surfaceHex: "101018",
            textHex: "FFFFFF",
            accentPrimaryHex: "6366F1",
            accentSecondaryHex: "8B5CF6",
            accentTertiaryHex: "EC4899",
            isDark: true
        )
    }
}
