import SwiftUI

enum LumiThemeEditor {
    static let appThemeId = "lumi"

    static func resolvedEditorThemeId(
        appThemeId: String,
        fallbackEditorThemeId: String,
        colorScheme: ColorScheme
    ) -> String {
        guard appThemeId == Self.appThemeId else {
            return fallbackEditorThemeId
        }
        return colorScheme == .dark ? "lumi-dark" : "lumi-light"
    }
}
