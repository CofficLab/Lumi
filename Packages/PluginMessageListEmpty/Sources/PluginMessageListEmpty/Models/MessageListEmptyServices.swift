import ProviderActivityBar
import ProviderConversation
import ProviderGit
import ProviderMessage
import ProviderPluginControl
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
    /// 插件启停控制。Git Workspace 默认禁用，点击项目的 Git 状态行时
    /// 需要先把它启用，否则 Activity Bar 里根本没有可激活的入口。
    let pluginControl: (any PluginControlling)?
    /// Rail view, used to jump to the project file tree.
    let railView: (any RailViewProviding)?

    /// `pluginControl` 有默认值：老调用点（预览、测试）可以不关心启停，
    /// 此时 Git 状态行只在入口已存在时才可点。
    init(
        project: (any ProjectProviding)?,
        promptSuggestions: (any PromptSuggestionProviding)?,
        promptSuggestionExecutor: (any PromptSuggestionExecuting)?,
        messages: (any MessageManaging)?,
        conversations: (any ConversationManaging)?,
        projectRAG: (any ProjectRAGProviding)?,
        git: (any GitRepositoryReading)?,
        activityBar: (any ActivityBarProviding)?,
        pluginControl: (any PluginControlling)? = nil,
        railView: (any RailViewProviding)?
    ) {
        self.project = project
        self.promptSuggestions = promptSuggestions
        self.promptSuggestionExecutor = promptSuggestionExecutor
        self.messages = messages
        self.conversations = conversations
        self.projectRAG = projectRAG
        self.git = git
        self.activityBar = activityBar
        self.pluginControl = pluginControl
        self.railView = railView
    }
}
