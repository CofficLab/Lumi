import Foundation

@MainActor
public final class EditorAppearanceController {
    public init() {}

    public func syncThemeSilently(
        currentThemeId: String,
        incomingThemeId: String
    ) -> Bool {
        currentThemeId != incomingThemeId
    }
}
