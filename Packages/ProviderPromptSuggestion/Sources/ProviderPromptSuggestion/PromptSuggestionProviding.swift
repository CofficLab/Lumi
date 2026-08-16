import Foundation

public struct PromptSuggestion: Identifiable, Sendable, Equatable {
    public let id: String; public let title: String; public let prompt: String; public let order: Int
    public init(id: String, title: String, prompt: String? = nil, order: Int = 0) { self.id = id; self.title = title; self.prompt = prompt ?? title; self.order = order }
}
@MainActor
public protocol PromptSuggestionProviding: AnyObject {
    var allSuggestions: [PromptSuggestion] { get }
    func register(_ suggestion: PromptSuggestion)
    func unregister(id: String)
    func removeAll()
}
@MainActor
public final class DefaultPromptSuggestionProviding: PromptSuggestionProviding {
    public private(set) var allSuggestions: [PromptSuggestion] = []
    public init() {}
    public func register(_ suggestion: PromptSuggestion) { allSuggestions.removeAll { $0.id == suggestion.id }; allSuggestions.append(suggestion); allSuggestions.sort { $0.order > $1.order } }
    public func unregister(id: String) { allSuggestions.removeAll { $0.id == id } }
    public func removeAll() { allSuggestions.removeAll() }
}
