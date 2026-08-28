import Combine

@MainActor
public protocol PromptSuggestionProviding: ObservableObject {
    var allSuggestions: [PromptSuggestion] { get }
    var changes: AnyPublisher<Void, Never> { get }
    func register(_ suggestion: PromptSuggestion)
    func unregister(id: String)
    func removeAll()
}
