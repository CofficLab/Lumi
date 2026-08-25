import Combine
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

public enum PromptSuggestionAction: Equatable, Sendable {
    case activateRailTab(id: String, viewContainerID: String)
    case activateViewContainer(String)
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

    public init(id: String, title: String, prompt: String? = nil, order: Int = 0,
                systemImage: String? = nil, action: PromptSuggestionAction? = nil,
                visibility: PromptSuggestionVisibility = .always,
                style: PromptSuggestionStyle = .standard) {
        self.id = id; self.title = title; self.prompt = prompt ?? title; self.order = order
        self.systemImage = systemImage; self.action = action
        self.visibility = visibility; self.style = style
    }
}

@MainActor
public protocol PromptSuggestionContributing: AnyObject {
    var promptSuggestions: [PromptSuggestion] { get }
}

@MainActor
public protocol PromptSuggestionProviding: ObservableObject {
    var allSuggestions: [PromptSuggestion] { get }
    func register(_ suggestion: PromptSuggestion)
    func unregister(id: String)
    func removeAll()
}
