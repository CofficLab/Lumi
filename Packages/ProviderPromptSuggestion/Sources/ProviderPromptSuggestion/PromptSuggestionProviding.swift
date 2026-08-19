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
