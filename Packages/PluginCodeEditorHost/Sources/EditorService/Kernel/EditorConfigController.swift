import Foundation
import CoreGraphics
import Combine
import EditorKernel

@MainActor
final class EditorConfigController {
    private let scopedOverridesKey = "scopedOverrides.v1"

    func restoreConfig(
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
            autoSaveMode: .off,
            autoSaveDelay: 1.0
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
        if let value = EditorConfigStore.loadString(forKey: EditorConfigStore.autoSaveModeKey),
           let mode = EditorAutoSaveMode(rawValue: value) {
            snapshot.autoSaveMode = mode
        }
        if let value = EditorConfigStore.loadDouble(forKey: EditorConfigStore.autoSaveDelayKey) {
            snapshot.autoSaveDelay = value
        }

        // 注意：主题 ID 不在此恢复，由 ThemeManagerPlugin 通过 AppThemeVM 驱动
        // EditorState 通过 observeThemeChanges() 监听通知来同步编辑器主题

        return snapshot
    }

    func restoreScopedConfig(
    ) -> EditorScopedConfigSnapshot {
        let global = restoreConfig()
        let rawScopes = EditorConfigStore.loadDictionary(forKey: scopedOverridesKey) ?? [:]
        let workspaceOverrides = EditorConfigPersistencePolicy.decodeOverrideMap(rawScopes["workspace"] as? [String: Any])
        let languageOverrides = EditorConfigPersistencePolicy.decodeOverrideMap(rawScopes["language"] as? [String: Any])
        return EditorScopedConfigSnapshot(
            global: global,
            workspaceOverrides: workspaceOverrides,
            languageOverrides: languageOverrides
        )
    }

    func resolveConfig(
        for context: EditorConfigContext
    ) -> EditorConfigSnapshot {
        EditorConfigPersistencePolicy.resolveConfig(for: context, scoped: restoreScopedConfig())
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
        EditorConfigStore.saveValue(snapshot.autoSaveMode.rawValue, forKey: EditorConfigStore.autoSaveModeKey)
        EditorConfigStore.saveValue(snapshot.autoSaveDelay, forKey: EditorConfigStore.autoSaveDelayKey)
        // 注意：currentThemeId 不在此持久化，主题持久化由 ThemeManagerPlugin 全权负责
    }

    func overrideSnapshot(
        for scope: EditorConfigOverrideScope
    ) -> EditorScopedOverrideSnapshot {
        EditorConfigPersistencePolicy.overrideSnapshot(in: restoreScopedConfig(), for: scope)
    }

    func persistOverrideSnapshot(
        _ overrideSnapshot: EditorScopedOverrideSnapshot,
        for scope: EditorConfigOverrideScope
    ) {
        let scoped = EditorConfigPersistencePolicy.updating(
            restoreScopedConfig(),
            overrideSnapshot: overrideSnapshot,
            for: scope
        )
        persistScopedOverrides(scoped)
    }

    func observeThemeChanges(
        applyResolvedThemeID: @escaping @MainActor (_ themeId: String, _ shouldRegisterThemeContributors: Bool) -> Void
    ) -> AnyCancellable {
        let notificationName = EditorHostEnvironment.current.notifications.themeDidChange
        return NotificationCenter.default
            .publisher(for: notificationName)
            .receive(on: RunLoop.main)
            .sink { notification in
                let editorThemeId: String = {
                    if let id = notification.userInfo?["editorThemeId"] as? String {
                        return id
                    }
                    if let themeId = notification.userInfo?["themeId"] as? String,
                       let map = EditorSettingsLifecycle.editorThemeIDForAppThemeID {
                        return map(themeId)
                    }
                    return "xcode-dark"
                }()
                Task { @MainActor in
                    applyResolvedThemeID(editorThemeId, true)
                }
            }
    }

    private func persistScopedOverrides(_ scopedSnapshot: EditorScopedConfigSnapshot) {
        let workspaceOverrides = EditorConfigPersistencePolicy.encodeOverrideMap(scopedSnapshot.workspaceOverrides)
        let languageOverrides = EditorConfigPersistencePolicy.encodeOverrideMap(scopedSnapshot.languageOverrides)
        if workspaceOverrides.isEmpty && languageOverrides.isEmpty {
            EditorConfigStore.removeValue(forKey: scopedOverridesKey)
            return
        }

        EditorConfigStore.saveValue(
            [
                "workspace": workspaceOverrides,
                "language": languageOverrides,
            ],
            forKey: scopedOverridesKey
        )
    }
}
