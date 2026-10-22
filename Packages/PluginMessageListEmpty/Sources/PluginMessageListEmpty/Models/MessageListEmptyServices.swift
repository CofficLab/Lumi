import ProviderActivityBar
import ProviderConversation
import ProviderGit
import ProviderMessage
import ProviderProject
import ProviderProjectRAG
import ProviderPromptSuggestion
import ProviderRailView

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
    /// Conversation store, used by the project context card: it answers
    /// "how many conversations does this project have" and "which one was
    /// last used", and it is the only place that knows the project ↔
    /// conversation mapping.
    let conversations: (any ConversationManaging)?
    /// Project index status. `nil` when the RAG plugin is disabled, in which
    /// case the index row is simply not rendered.
    let projectRAG: (any ProjectRAGProviding)?
    /// Git repository state. `nil` when the Git plugin is disabled; the
    /// uncommitted-changes row then disappears instead of showing a dash.
    let git: (any GitRepositoryReading)?
    /// Activity bar, used to jump to the Git workspace panel.
    let activityBar: (any ActivityBarProviding)?
    /// Rail view, used to jump to the project file tree.
    let railView: (any RailViewProviding)?
}
