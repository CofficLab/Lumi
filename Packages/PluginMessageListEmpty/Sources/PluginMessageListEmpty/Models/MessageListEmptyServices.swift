import ProviderMessage
import ProviderProject
import ProviderPromptSuggestion

@MainActor
struct MessageListEmptyServices {
    let project: (any ProjectProviding)?
    let promptSuggestions: (any PromptSuggestionProviding)?
    let promptSuggestionExecutor: (any PromptSuggestionExecuting)?
    /// Cross-conversation message statistics for the empty-state activity strip.
    ///
    /// Injected rather than resolved by the views so the plugin keeps ownership
    /// of every external dependency.
    let messages: (any MessageManaging)?
}
