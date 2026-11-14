import ProviderPromptSuggestion

/// 提示建议展示所需的最小能力。
@MainActor
public protocol MessageListPromptSuggestionCapability: AnyObject {
    var allSuggestions: [PromptSuggestion] { get }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PromptSuggestionProvidingEvent) -> Void
    ) -> any PromptSuggestionProvidingObserverHandle
}

@MainActor
public final class MessageListPromptSuggestionCapabilityAdapter: MessageListPromptSuggestionCapability {
    private let promptSuggestions: any PromptSuggestionProviding
    public init(promptSuggestions: any PromptSuggestionProviding) { self.promptSuggestions = promptSuggestions }
    public var allSuggestions: [PromptSuggestion] { promptSuggestions.allSuggestions }

    @discardableResult
    public func addObserver(
        _ callback: @escaping (PromptSuggestionProvidingEvent) -> Void
    ) -> any PromptSuggestionProvidingObserverHandle {
        promptSuggestions.addObserver(callback)
    }
}