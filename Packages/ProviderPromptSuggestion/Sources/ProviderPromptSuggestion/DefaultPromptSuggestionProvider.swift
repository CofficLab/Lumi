import SwiftUI

@MainActor
public final class DefaultPromptSuggestionProvider: PromptSuggestionProviding {
    public private(set) var allSuggestions: [PromptSuggestion] = []

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
