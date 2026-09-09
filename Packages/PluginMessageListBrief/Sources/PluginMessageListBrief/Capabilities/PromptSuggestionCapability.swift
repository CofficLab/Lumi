import ProviderPromptSuggestion

/// 提示建议展示所需的最小能力。
@MainActor
protocol MessageListPromptSuggestionCapability: AnyObject {
    var allSuggestions: [PromptSuggestion] { get }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PromptSuggestionProvidingEvent) -> Void
    ) -> any PromptSuggestionProvidingObserverHandle
}

@MainActor
final class MessageListPromptSuggestionCapabilityAdapter: MessageListPromptSuggestionCapability {
    private let promptSuggestions: any PromptSuggestionProviding

    init(promptSuggestions: any PromptSuggestionProviding) {
        self.promptSuggestions = promptSuggestions
    }

    var allSuggestions: [PromptSuggestion] { promptSuggestions.allSuggestions }

    @discardableResult
    func addObserver(
        _ callback: @escaping (PromptSuggestionProvidingEvent) -> Void
    ) -> any PromptSuggestionProvidingObserverHandle {
        promptSuggestions.addObserver(callback)
    }
}
