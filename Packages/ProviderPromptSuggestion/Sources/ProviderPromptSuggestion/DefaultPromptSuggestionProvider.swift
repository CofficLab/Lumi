import Combine
import SwiftUI

@MainActor
public final class DefaultPromptSuggestionProvider: PromptSuggestionProviding {
    public private(set) var allSuggestions: [PromptSuggestion] = []

    public var changes: AnyPublisher<Void, Never> {
        objectWillChange
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    public init() {}

    public func register(_ suggestion: PromptSuggestion) {
        allSuggestions.removeAll { $0.id == suggestion.id }
        allSuggestions.append(suggestion)
        allSuggestions.sort { $0.order < $1.order }
    }

    public func unregister(id: String) {
        allSuggestions.removeAll { $0.id == id }
    }

    public func removeAll() {
        allSuggestions.removeAll()
    }
}
