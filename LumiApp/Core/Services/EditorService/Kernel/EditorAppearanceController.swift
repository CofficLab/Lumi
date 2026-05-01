import Foundation
import CoreGraphics

@MainActor
final class EditorAppearanceController {
    func clampedSidePanelWidth(_ width: Double) -> CGFloat {
        CGFloat(min(max(width, 240), 720))
    }

    func applyRestoredConfig(
        using configController: EditorConfigController
    ) -> EditorConfigSnapshot {
        configController.restoreConfig(clampedSidePanelWidth: clampedSidePanelWidth(_:))
    }

    func persistSidePanelWidth(_ width: CGFloat) {
        EditorConfigStore.saveValue(width, forKey: EditorConfigStore.sidePanelWidthKey)
    }

    func updateSidePanelWidth(
        currentWidth: CGFloat,
        delta: CGFloat
    ) -> CGFloat {
        clampedSidePanelWidth(currentWidth + delta)
    }

    func syncThemeSilently(
        currentThemeId: String,
        incomingThemeId: String
    ) -> Bool {
        currentThemeId != incomingThemeId
    }
}
