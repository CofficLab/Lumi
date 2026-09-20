import Foundation

public struct EditorConfigContext: Equatable {
    public var workspacePath: String?
    public var languageId: String?

    public init(workspacePath: String? = nil, languageId: String? = nil) {
        self.workspacePath = workspacePath
        self.languageId = languageId
    }

    public var normalizedWorkspacePath: String? {
        Self.normalizePath(workspacePath)
    }

    public var normalizedLanguageId: String? {
        Self.normalizeLanguageId(languageId)
    }

    public static func normalizePath(_ path: String?) -> String? {
        guard let trimmed = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: trimmed).standardizedFileURL.path
    }

    public static func normalizeLanguageId(_ languageId: String?) -> String? {
        guard let trimmed = languageId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed.lowercased()
    }
}

public enum EditorConfigOverrideScope: Equatable {
    case workspace(String)
    case language(String)

    public var normalizedKey: String {
        switch self {
        case let .workspace(path):
            return EditorConfigContext.normalizePath(path) ?? path
        case let .language(languageId):
            return EditorConfigContext.normalizeLanguageId(languageId) ?? languageId.lowercased()
        }
    }
}

public struct EditorScopedOverrideSnapshot: Equatable {
    public var tabWidth: Int?
    public var useSpaces: Bool?
    public var wrapLines: Bool?
    public var formatOnSave: Bool?

    public init(
        tabWidth: Int? = nil,
        useSpaces: Bool? = nil,
        wrapLines: Bool? = nil,
        formatOnSave: Bool? = nil
    ) {
        self.tabWidth = tabWidth
        self.useSpaces = useSpaces
        self.wrapLines = wrapLines
        self.formatOnSave = formatOnSave
    }

    public var isEmpty: Bool {
        tabWidth == nil &&
        useSpaces == nil &&
        wrapLines == nil &&
        formatOnSave == nil
    }

    public func applying(to snapshot: EditorConfigSnapshot) -> EditorConfigSnapshot {
        var resolved = snapshot
        if let tabWidth { resolved.tabWidth = tabWidth }
        if let useSpaces { resolved.useSpaces = useSpaces }
        if let wrapLines { resolved.wrapLines = wrapLines }
        if let formatOnSave { resolved.formatOnSave = formatOnSave }
        return resolved
    }

    public static func from(dictionary: [String: Any]) -> EditorScopedOverrideSnapshot {
        EditorScopedOverrideSnapshot(
            tabWidth: dictionary["tabWidth"] as? Int,
            useSpaces: dictionary["useSpaces"] as? Bool,
            wrapLines: dictionary["wrapLines"] as? Bool,
            formatOnSave: dictionary["formatOnSave"] as? Bool
        )
    }

    public var dictionaryRepresentation: [String: Any] {
        var dictionary: [String: Any] = [:]
        if let tabWidth { dictionary["tabWidth"] = tabWidth }
        if let useSpaces { dictionary["useSpaces"] = useSpaces }
        if let wrapLines { dictionary["wrapLines"] = wrapLines }
        if let formatOnSave { dictionary["formatOnSave"] = formatOnSave }
        return dictionary
    }
}

public struct EditorScopedConfigSnapshot: Equatable {
    public var global: EditorConfigSnapshot
    public var workspaceOverrides: [String: EditorScopedOverrideSnapshot]
    public var languageOverrides: [String: EditorScopedOverrideSnapshot]

    public init(
        global: EditorConfigSnapshot,
        workspaceOverrides: [String: EditorScopedOverrideSnapshot],
        languageOverrides: [String: EditorScopedOverrideSnapshot]
    ) {
        self.global = global
        self.workspaceOverrides = workspaceOverrides
        self.languageOverrides = languageOverrides
    }
}

public struct EditorConfigSnapshot: Equatable {
    public var fontSize: Double
    public var tabWidth: Int
    public var useSpaces: Bool
    public var formatOnSave: Bool
    public var organizeImportsOnSave: Bool
    public var fixAllOnSave: Bool
    public var trimTrailingWhitespaceOnSave: Bool
    public var insertFinalNewlineOnSave: Bool
    public var wrapLines: Bool
    public var showMinimap: Bool
    public var showGutter: Bool
    public var showFoldingRibbon: Bool
    public var currentThemeId: String
    public var autoSaveMode: EditorAutoSaveMode
    public var autoSaveDelay: Double

    public init(
        fontSize: Double,
        tabWidth: Int,
        useSpaces: Bool,
        formatOnSave: Bool,
        organizeImportsOnSave: Bool,
        fixAllOnSave: Bool,
        trimTrailingWhitespaceOnSave: Bool,
        insertFinalNewlineOnSave: Bool,
        wrapLines: Bool,
        showMinimap: Bool,
        showGutter: Bool,
        showFoldingRibbon: Bool,
        currentThemeId: String,
        autoSaveMode: EditorAutoSaveMode = .off,
        autoSaveDelay: Double = 1.0
    ) {
        self.fontSize = fontSize
        self.tabWidth = tabWidth
        self.useSpaces = useSpaces
        self.formatOnSave = formatOnSave
        self.organizeImportsOnSave = organizeImportsOnSave
        self.fixAllOnSave = fixAllOnSave
        self.trimTrailingWhitespaceOnSave = trimTrailingWhitespaceOnSave
        self.insertFinalNewlineOnSave = insertFinalNewlineOnSave
        self.wrapLines = wrapLines
        self.showMinimap = showMinimap
        self.showGutter = showGutter
        self.showFoldingRibbon = showFoldingRibbon
        self.currentThemeId = currentThemeId
        self.autoSaveMode = autoSaveMode
        self.autoSaveDelay = autoSaveDelay
    }
}
