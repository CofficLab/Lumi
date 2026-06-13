import LumiUI
import SwiftUI

extension SkyTheme {
    func editorSyntaxPalette(colorScheme: ColorScheme) -> EditorSyntaxPalette {
        colorScheme == .dark ? .preset(.skyDark) : .preset(.skyLight)
    }
}
