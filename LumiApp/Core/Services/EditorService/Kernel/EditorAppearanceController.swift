import Foundation
import CoreGraphics

@MainActor
final class EditorAppearanceController {
    func syncThemeSilently(
        currentThemeId: String,
        incomingThemeId: String
    ) -> Bool {
        currentThemeId != incomingThemeId
    }
}
