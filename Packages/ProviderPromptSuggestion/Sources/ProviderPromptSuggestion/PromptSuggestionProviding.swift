import Foundation

@MainActor
public enum PromptSuggestionProvidingEvent: Sendable, Equatable {
    case suggestionsChanged([PromptSuggestion])
}

@MainActor
public protocol PromptSuggestionProvidingObserverHandle: AnyObject {
    func cancel()
}

@MainActor
public final class NoopPromptSuggestionProvidingObserverHandle: PromptSuggestionProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}

@MainActor
public protocol PromptSuggestionProviding: AnyObject {
    var allSuggestions: [PromptSuggestion] { get }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PromptSuggestionProvidingEvent) -> Void
    ) -> any PromptSuggestionProvidingObserverHandle

    func register(_ suggestion: PromptSuggestion)
    func unregister(id: String)
    func removeAll()
}
