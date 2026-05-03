import Foundation
import CoreGraphics

struct EditorConfigContext: Equatable {
    var workspacePath: String?
    var languageId: String?

    var normalizedWorkspacePath: String? {
        Self.normalizePath(workspacePath)
    }

    var normalizedLanguageId: String? {
        Self.normalizeLanguageId(languageId)
    }

    static func normalizePath(_ path: String?) -> String? {
        guard let trimmed = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: trimmed).standardizedFileURL.path
    }

    static func normalizeLanguageId(_ languageId: String?) -> String? {
        guard let trimmed = languageId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed.lowercased()
    }
}

enum EditorConfigOverrideScope: Equatable {
    case workspace(String)
    case language(String)

    var normalizedKey: String {
        switch self {
        case let .workspace(path):
            return EditorConfigContext.normalizePath(path) ?? path
        case let .language(languageId):
            return EditorConfigContext.normalizeLanguageId(languageId) ?? languageId.lowercased()
        }
    }
}

struct EditorScopedOverrideSnapshot: Equatable {
    var tabWidth: Int?
    var useSpaces: Bool?
    var wrapLines: Bool?
    var formatOnSave: Bool?

    var isEmpty: Bool {
        tabWidth == nil &&
        useSpaces == nil &&
        wrapLines == nil &&
        formatOnSave == nil
    }

    func applying(to snapshot: EditorConfigSnapshot) -> EditorConfigSnapshot {
        var resolved = snapshot
        if let tabWidth { resolved.tabWidth = tabWidth }
        if let useSpaces { resolved.useSpaces = useSpaces }
        if let wrapLines { resolved.wrapLines = wrapLines }
        if let formatOnSave { resolved.formatOnSave = formatOnSave }
        return resolved
    }

    static func from(dictionary: [String: Any]) -> EditorScopedOverrideSnapshot {
        EditorScopedOverrideSnapshot(
            tabWidth: dictionary["tabWidth"] as? Int,
            useSpaces: dictionary["useSpaces"] as? Bool,
            wrapLines: dictionary["wrapLines"] as? Bool,
            formatOnSave: dictionary["formatOnSave"] as? Bool
        )
    }

    var dictionaryRepresentation: [String: Any] {
        var dictionary: [String: Any] = [:]
        if let tabWidth { dictionary["tabWidth"] = tabWidth }
        if let useSpaces { dictionary["useSpaces"] = useSpaces }
        if let wrapLines { dictionary["wrapLines"] = wrapLines }
        if let formatOnSave { dictionary["formatOnSave"] = formatOnSave }
        return dictionary
    }
}

struct EditorScopedConfigSnapshot: Equatable {
    var global: EditorConfigSnapshot
    var workspaceOverrides: [String: EditorScopedOverrideSnapshot]
    var languageOverrides: [String: EditorScopedOverrideSnapshot]
}

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
}

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

        if let appThemeId = ThemeVM.loadSavedThemeId() {
            snapshot.currentThemeId = ThemeVM.editorThemeID(for: appThemeId)
        } else if let themeRaw = EditorConfigStore.loadString(forKey: EditorConfigStore.themeNameKey) {
            snapshot.currentThemeId = themeRaw
        }

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
        EditorConfigStore.saveValue(snapshot.currentThemeId, forKey: EditorConfigStore.themeNameKey)
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
