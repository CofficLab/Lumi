import LumiUI
import SwiftUI

extension LumiTheme {
    func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        colorScheme == .dark ? .preset(.lumiDark) : .preset(.lumiLight)
    }
}
