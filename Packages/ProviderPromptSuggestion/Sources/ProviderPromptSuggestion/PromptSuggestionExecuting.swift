import Foundation

/// Executes a registered prompt suggestion.
@MainActor
public protocol PromptSuggestionExecuting: AnyObject {
    func execute(
        _ suggestion: PromptSuggestion,
        pickProjectFolder: (() -> Void)?
    ) async
}
