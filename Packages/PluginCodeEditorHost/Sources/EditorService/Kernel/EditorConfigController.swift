import Foundation
import CoreGraphics
import Combine
import EditorKernel

@MainActor
final class EditorConfigController {
    private let scopedOverridesKey = "scopedOverrides.v1"

    func restoreConfig(
    ) -> EditorConfigSnapshot {
        // 整份字典只加载/解码一次，各键在内存里读取（见 issue #1250）。
        snapshot(from: EditorConfigStore.loadAll())
    }

    /// 从已加载的配置字典构造全局快照，避免逐键重复读盘 + plist 解码。
    private func snapshot(from dict: [String: Any]) -> EditorConfigSnapshot {
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

        if let value = dict[EditorConfigStore.fontSizeKey] as? Double { snapshot.fontSize = value }
        if let value = dict[EditorConfigStore.tabWidthKey] as? Int { snapshot.tabWidth = value }
        if let value = dict[EditorConfigStore.useSpacesKey] as? Bool { snapshot.useSpaces = value }
        if let value = dict[EditorConfigStore.formatOnSaveKey] as? Bool { snapshot.formatOnSave = value }
        if let value = dict[EditorConfigStore.organizeImportsOnSaveKey] as? Bool { snapshot.organizeImportsOnSave = value }
        if let value = dict[EditorConfigStore.fixAllOnSaveKey] as? Bool { snapshot.fixAllOnSave = value }
        if let value = dict[EditorConfigStore.trimTrailingWhitespaceOnSaveKey] as? Bool { snapshot.trimTrailingWhitespaceOnSave = value }
        if let value = dict[EditorConfigStore.insertFinalNewlineOnSaveKey] as? Bool { snapshot.insertFinalNewlineOnSave = value }
        if let value = dict[EditorConfigStore.wrapLinesKey] as? Bool { snapshot.wrapLines = value }
        if let value = dict[EditorConfigStore.showMinimapKey] as? Bool { snapshot.showMinimap = value }
        if let value = dict[EditorConfigStore.showGutterKey] as? Bool { snapshot.showGutter = value }
        if let value = dict[EditorConfigStore.showFoldingRibbonKey] as? Bool { snapshot.showFoldingRibbon = value }
        if let value = dict[EditorConfigStore.autoSaveModeKey] as? String,
           let mode = EditorAutoSaveMode(rawValue: value) {
            snapshot.autoSaveMode = mode
        }
        if let value = dict[EditorConfigStore.autoSaveDelayKey] as? Double {
            snapshot.autoSaveDelay = value
        }

        // 注意：主题 ID 不在此恢复，由 ThemeManagerPlugin 通过 AppThemeVM 驱动
        // EditorState 通过 observeThemeChanges() 监听通知来同步编辑器主题

        return snapshot
    }

    func restoreScopedConfig(
    ) -> EditorScopedConfigSnapshot {
        // 全局快照与 scoped overrides 共用同一次加载（见 issue #1250）。
        let dict = EditorConfigStore.loadAll()
        let global = snapshot(from: dict)
        let rawScopes = dict[scopedOverridesKey] as? [String: Any] ?? [:]
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
        // 全部键合并成一次读-改-写，避免逐键重复整份 plist 的加载/编码/落盘（见 issue #1250）。
        let values: [String: Any] = [
            EditorConfigStore.fontSizeKey: snapshot.fontSize,
            EditorConfigStore.tabWidthKey: snapshot.tabWidth,
            EditorConfigStore.useSpacesKey: snapshot.useSpaces,
            EditorConfigStore.formatOnSaveKey: snapshot.formatOnSave,
            EditorConfigStore.organizeImportsOnSaveKey: snapshot.organizeImportsOnSave,
            EditorConfigStore.fixAllOnSaveKey: snapshot.fixAllOnSave,
            EditorConfigStore.trimTrailingWhitespaceOnSaveKey: snapshot.trimTrailingWhitespaceOnSave,
            EditorConfigStore.insertFinalNewlineOnSaveKey: snapshot.insertFinalNewlineOnSave,
            EditorConfigStore.wrapLinesKey: snapshot.wrapLines,
            EditorConfigStore.showMinimapKey: snapshot.showMinimap,
            EditorConfigStore.showGutterKey: snapshot.showGutter,
            EditorConfigStore.showFoldingRibbonKey: snapshot.showFoldingRibbon,
            EditorConfigStore.autoSaveModeKey: snapshot.autoSaveMode.rawValue,
            EditorConfigStore.autoSaveDelayKey: snapshot.autoSaveDelay,
        ]
        EditorConfigStore.saveValues(values)
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
