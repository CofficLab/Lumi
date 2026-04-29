import Foundation
import CoreGraphics

struct EditorConfigSnapshot: Equatable {
    var fontSize: Double
    var tabWidth: Int
    var useSpaces: Bool
    var formatOnSave: Bool
    var organizeImportsOnSave: Bool
    var fixAllOnSave: Bool
    var trimTrailingWhitespaceOnSave: Bool
    var insertFinalNewlineOnSave: Bool
    var wrapLines: Bool
    var showMinimap: Bool
    var showGutter: Bool
    var showFoldingRibbon: Bool
    var currentThemeId: String
    var sidePanelWidth: CGFloat
}

@MainActor
final class EditorConfigController {
    func restoreConfig(
        clampedSidePanelWidth: (Double) -> CGFloat
    ) -> EditorConfigSnapshot {
        var snapshot = EditorConfigSnapshot(
            fontSize: 13.0,
            tabWidth: 4,
            useSpaces: true,
            formatOnSave: false,
            organizeImportsOnSave: false,
            fixAllOnSave: false,
            trimTrailingWhitespaceOnSave: true,
            insertFinalNewlineOnSave: true,
            wrapLines: true,
            showMinimap: true,
            showGutter: true,
            showFoldingRibbon: true,
            currentThemeId: "xcode-dark",
            sidePanelWidth: 360
        )

        if let value = EditorConfigStore.loadDouble(forKey: EditorConfigStore.fontSizeKey) { snapshot.fontSize = value }
        if let value = EditorConfigStore.loadInt(forKey: EditorConfigStore.tabWidthKey) { snapshot.tabWidth = value }
        if let value = EditorConfigStore.loadBool(forKey: EditorConfigStore.useSpacesKey) { snapshot.useSpaces = value }
        if let value = EditorConfigStore.loadBool(forKey: EditorConfigStore.formatOnSaveKey) { snapshot.formatOnSave = value }
        if let value = EditorConfigStore.loadBool(forKey: EditorConfigStore.organizeImportsOnSaveKey) { snapshot.organizeImportsOnSave = value }
        if let value = EditorConfigStore.loadBool(forKey: EditorConfigStore.fixAllOnSaveKey) { snapshot.fixAllOnSave = value }
        if let value = EditorConfigStore.loadBool(forKey: EditorConfigStore.trimTrailingWhitespaceOnSaveKey) { snapshot.trimTrailingWhitespaceOnSave = value }
        if let value = EditorConfigStore.loadBool(forKey: EditorConfigStore.insertFinalNewlineOnSaveKey) { snapshot.insertFinalNewlineOnSave = value }
        if let value = EditorConfigStore.loadBool(forKey: EditorConfigStore.wrapLinesKey) { snapshot.wrapLines = value }
        if let value = EditorConfigStore.loadBool(forKey: EditorConfigStore.showMinimapKey) { snapshot.showMinimap = value }
        if let value = EditorConfigStore.loadBool(forKey: EditorConfigStore.showGutterKey) { snapshot.showGutter = value }
        if let value = EditorConfigStore.loadBool(forKey: EditorConfigStore.showFoldingRibbonKey) { snapshot.showFoldingRibbon = value }
        if let value = EditorConfigStore.loadDouble(forKey: EditorConfigStore.sidePanelWidthKey) {
            snapshot.sidePanelWidth = clampedSidePanelWidth(value)
        }

        if let appThemeId = ThemeManager.loadSavedThemeId() {
            snapshot.currentThemeId = ThemeManager.editorThemeID(for: appThemeId)
        } else if let themeRaw = EditorConfigStore.loadString(forKey: EditorConfigStore.themeNameKey) {
            snapshot.currentThemeId = themeRaw
        }

        return snapshot
    }

    func persistConfig(_ snapshot: EditorConfigSnapshot) {
        EditorConfigStore.saveValue(snapshot.fontSize, forKey: EditorConfigStore.fontSizeKey)
        EditorConfigStore.saveValue(snapshot.tabWidth, forKey: EditorConfigStore.tabWidthKey)
        EditorConfigStore.saveValue(snapshot.useSpaces, forKey: EditorConfigStore.useSpacesKey)
        EditorConfigStore.saveValue(snapshot.formatOnSave, forKey: EditorConfigStore.formatOnSaveKey)
        EditorConfigStore.saveValue(snapshot.organizeImportsOnSave, forKey: EditorConfigStore.organizeImportsOnSaveKey)
        EditorConfigStore.saveValue(snapshot.fixAllOnSave, forKey: EditorConfigStore.fixAllOnSaveKey)
        EditorConfigStore.saveValue(snapshot.trimTrailingWhitespaceOnSave, forKey: EditorConfigStore.trimTrailingWhitespaceOnSaveKey)
        EditorConfigStore.saveValue(snapshot.insertFinalNewlineOnSave, forKey: EditorConfigStore.insertFinalNewlineOnSaveKey)
        EditorConfigStore.saveValue(snapshot.wrapLines, forKey: EditorConfigStore.wrapLinesKey)
        EditorConfigStore.saveValue(snapshot.showMinimap, forKey: EditorConfigStore.showMinimapKey)
        EditorConfigStore.saveValue(snapshot.showGutter, forKey: EditorConfigStore.showGutterKey)
        EditorConfigStore.saveValue(snapshot.showFoldingRibbon, forKey: EditorConfigStore.showFoldingRibbonKey)
        EditorConfigStore.saveValue(snapshot.currentThemeId, forKey: EditorConfigStore.themeNameKey)
        EditorConfigStore.saveValue(snapshot.sidePanelWidth, forKey: EditorConfigStore.sidePanelWidthKey)
    }

    func observeThemeChanges(
        applyResolvedThemeID: @escaping @MainActor (_ themeId: String, _ shouldRegisterThemeContributors: Bool) -> Void
    ) {
        NotificationCenter.default.addObserver(
            forName: .lumiThemeDidChange,
            object: nil,
            queue: .main
        ) { notification in
            let editorThemeId = (notification.userInfo?["editorThemeId"] as? String)
                ?? (notification.userInfo?["themeId"] as? String).map { ThemeManager.editorThemeID(for: $0) }
                ?? "xcode-dark"
            Task { @MainActor in
                applyResolvedThemeID(editorThemeId, true)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .lumiEditorThemeDidChange,
            object: nil,
            queue: .main
        ) { notification in
            guard let themeId = notification.userInfo?["themeId"] as? String else { return }
            Task { @MainActor in
                applyResolvedThemeID(themeId, false)
            }
        }
    }
}
