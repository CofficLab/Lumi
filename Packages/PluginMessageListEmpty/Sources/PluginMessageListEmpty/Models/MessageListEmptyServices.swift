import ProviderProject
import ProviderPromptSuggestion

@MainActor
struct MessageListEmptyServices {
    let project: (any ProjectProviding)?
    let promptSuggestions: (any PromptSuggestionProviding)?
    let promptSuggestionExecutor: (any PromptSuggestionExecuting)?
}
