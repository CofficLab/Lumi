import Foundation
import CoreGraphics

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
            currentThemeId: "xcode-dark"
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

        // 注意：主题 ID 不在此恢复，由 ThemeStatusBarPlugin 通过 ThemeVM 驱动
        // EditorState 通过 observeThemeChanges() 监听通知来同步编辑器主题

        return snapshot
    }

    func restoreScopedConfig(
    ) -> EditorScopedConfigSnapshot {
        let global = restoreConfig()
        let rawScopes = EditorConfigStore.loadDictionary(forKey: scopedOverridesKey) ?? [:]
        let workspaceOverrides = decodeOverrideMap(rawScopes["workspace"] as? [String: Any])
        let languageOverrides = decodeOverrideMap(rawScopes["language"] as? [String: Any])
        return EditorScopedConfigSnapshot(
            global: global,
            workspaceOverrides: workspaceOverrides,
            languageOverrides: languageOverrides
        )
    }

    func resolveConfig(
        for context: EditorConfigContext
    ) -> EditorConfigSnapshot {
        let scoped = restoreScopedConfig()
        var resolved = scoped.global

        if let workspacePath = context.normalizedWorkspacePath,
           let workspaceOverride = scoped.workspaceOverrides[workspacePath] {
            resolved = workspaceOverride.applying(to: resolved)
        }

        if let languageId = context.normalizedLanguageId,
           let languageOverride = scoped.languageOverrides[languageId] {
            resolved = languageOverride.applying(to: resolved)
        }

        return resolved
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
        // 注意：currentThemeId 不在此持久化，主题持久化由 ThemeStatusBarPlugin 全权负责
    }

    func overrideSnapshot(
        for scope: EditorConfigOverrideScope
    ) -> EditorScopedOverrideSnapshot {
        let scoped = restoreScopedConfig()
        switch scope {
        case let .workspace(path):
            return scoped.workspaceOverrides[EditorConfigContext.normalizePath(path) ?? path] ?? EditorScopedOverrideSnapshot()
        case let .language(languageId):
            return scoped.languageOverrides[EditorConfigContext.normalizeLanguageId(languageId) ?? languageId.lowercased()] ?? EditorScopedOverrideSnapshot()
        }
    }

    func persistOverrideSnapshot(
        _ overrideSnapshot: EditorScopedOverrideSnapshot,
        for scope: EditorConfigOverrideScope
    ) {
        var scoped = restoreScopedConfig()
        switch scope {
        case let .workspace(path):
            let normalized = EditorConfigContext.normalizePath(path) ?? path
            if overrideSnapshot.isEmpty {
                scoped.workspaceOverrides.removeValue(forKey: normalized)
            } else {
                scoped.workspaceOverrides[normalized] = overrideSnapshot
            }
        case let .language(languageId):
            let normalized = EditorConfigContext.normalizeLanguageId(languageId) ?? languageId.lowercased()
            if overrideSnapshot.isEmpty {
                scoped.languageOverrides.removeValue(forKey: normalized)
            } else {
                scoped.languageOverrides[normalized] = overrideSnapshot
            }
        }
        persistScopedOverrides(scoped)
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
                ?? (notification.userInfo?["themeId"] as? String).map { ThemeVM.editorThemeID(for: $0) }
                ?? "xcode-dark"
            Task { @MainActor in
                applyResolvedThemeID(editorThemeId, true)
            }
        }


    }

    private func persistScopedOverrides(_ scopedSnapshot: EditorScopedConfigSnapshot) {
        let workspaceOverrides = encodeOverrideMap(scopedSnapshot.workspaceOverrides)
        let languageOverrides = encodeOverrideMap(scopedSnapshot.languageOverrides)
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

    private func decodeOverrideMap(_ raw: [String: Any]?) -> [String: EditorScopedOverrideSnapshot] {
        guard let raw else { return [:] }
        return raw.reduce(into: [:]) { partialResult, pair in
            guard let dictionary = pair.value as? [String: Any] else { return }
            partialResult[pair.key] = EditorScopedOverrideSnapshot.from(dictionary: dictionary)
        }
    }

    private func encodeOverrideMap(_ overrides: [String: EditorScopedOverrideSnapshot]) -> [String: Any] {
        overrides.reduce(into: [:]) { partialResult, pair in
            guard !pair.value.isEmpty else { return }
            partialResult[pair.key] = pair.value.dictionaryRepresentation
        }
    }
}
