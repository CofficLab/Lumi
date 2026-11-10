import Foundation

public enum PromptSuggestionVisibility: Equatable, Sendable {
    case always
    case onlyWithProject
    case onlyWithoutProject
}

public enum PromptSuggestionStyle: Equatable, Sendable {
    case standard
    case additive
}

/// Controls where a prompt suggestion is useful.
///
/// `launcher` suggestions help users enter a plugin workflow from the default
/// chat. They are intentionally hidden after another plugin context is active.
/// `launcherAndContext` keeps the same suggestion available as the active
/// plugin's primary entry after that workflow has been opened.
public enum PromptSuggestionScope: Equatable, Sendable {
    case global
    case launcher
    case context(String)
    case launcherAndContext(String)
}

public enum PromptSuggestionAction: Equatable, Sendable {
    case activatePluginEntry(
        activityBarItemID: String,
        railTabID: String
    )
    case activateRailTab(id: String)
    case pickProjectFolder
    case openSettingsTab(String)
}

public struct PromptSuggestion: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let prompt: String
    public var order: Int
    public let systemImage: String?
    public let action: PromptSuggestionAction?
    public let visibility: PromptSuggestionVisibility
    public let style: PromptSuggestionStyle
    public let scope: PromptSuggestionScope
    /// Filled by the composition root when the suggestion is collected.
    public var pluginID: String?
    /// True when the source plugin is registered but currently disabled.
    public var requiresEnable: Bool

    public init(id: String, title: String, prompt: String? = nil, order: Int = 0,
                systemImage: String? = nil, action: PromptSuggestionAction? = nil,
                visibility: PromptSuggestionVisibility = .always,
                style: PromptSuggestionStyle = .standard,
                scope: PromptSuggestionScope = .global) {
        self.id = id; self.title = title; self.prompt = prompt ?? title; self.order = order
        self.systemImage = systemImage; self.action = action
        self.visibility = visibility; self.style = style; self.scope = scope
        self.pluginID = nil; self.requiresEnable = false
    }
}
