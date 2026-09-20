import Foundation

public enum EditorConfigPersistencePolicy {
    public static func resolveConfig(
        for context: EditorConfigContext,
        scoped: EditorScopedConfigSnapshot
    ) -> EditorConfigSnapshot {
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

    public static func overrideSnapshot(
        in scoped: EditorScopedConfigSnapshot,
        for scope: EditorConfigOverrideScope
    ) -> EditorScopedOverrideSnapshot {
        switch scope {
        case let .workspace(path):
            return scoped.workspaceOverrides[EditorConfigContext.normalizePath(path) ?? path] ?? EditorScopedOverrideSnapshot()
        case let .language(languageId):
            return scoped.languageOverrides[EditorConfigContext.normalizeLanguageId(languageId) ?? languageId.lowercased()] ?? EditorScopedOverrideSnapshot()
        }
    }

    public static func updating(
        _ scoped: EditorScopedConfigSnapshot,
        overrideSnapshot: EditorScopedOverrideSnapshot,
        for scope: EditorConfigOverrideScope
    ) -> EditorScopedConfigSnapshot {
        var updated = scoped
        switch scope {
        case let .workspace(path):
            let normalized = EditorConfigContext.normalizePath(path) ?? path
            if overrideSnapshot.isEmpty {
                updated.workspaceOverrides.removeValue(forKey: normalized)
            } else {
                updated.workspaceOverrides[normalized] = overrideSnapshot
            }
        case let .language(languageId):
            let normalized = EditorConfigContext.normalizeLanguageId(languageId) ?? languageId.lowercased()
            if overrideSnapshot.isEmpty {
                updated.languageOverrides.removeValue(forKey: normalized)
            } else {
                updated.languageOverrides[normalized] = overrideSnapshot
            }
        }
        return updated
    }

    public static func decodeOverrideMap(_ raw: [String: Any]?) -> [String: EditorScopedOverrideSnapshot] {
        guard let raw else { return [:] }
        return raw.reduce(into: [:]) { partialResult, pair in
            guard let dictionary = pair.value as? [String: Any] else { return }
            partialResult[pair.key] = EditorScopedOverrideSnapshot.from(dictionary: dictionary)
        }
    }

    public static func encodeOverrideMap(_ overrides: [String: EditorScopedOverrideSnapshot]) -> [String: Any] {
        overrides.reduce(into: [:]) { partialResult, pair in
            guard !pair.value.isEmpty else { return }
            partialResult[pair.key] = pair.value.dictionaryRepresentation
        }
    }
}
