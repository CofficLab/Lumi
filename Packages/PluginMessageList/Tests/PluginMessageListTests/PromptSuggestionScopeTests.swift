import ProviderChatSection
import ProviderPromptSuggestion
import Testing
@testable import PluginMessageList

@Suite("MessageList prompt suggestion scope")
@MainActor
struct PromptSuggestionScopeTests {
    @Test("默认聊天显示 launcher，插件上下文只显示 global 和自身提示词")
    func filtersSuggestionsByContext() {
        let global = PromptSuggestion(id: "global", title: "全局", scope: .global)
        let launcher = PromptSuggestion(id: "launcher", title: "打开插件", scope: .launcher)
        let activeLauncher = PromptSuggestion(
            id: "active-launcher",
            title: "当前插件入口",
            scope: .launcherAndContext("plugin.story")
        )
        let story = PromptSuggestion(id: "story", title: "创建故事", scope: .context("plugin.story"))
        let resume = PromptSuggestion(id: "resume", title: "创建简历", scope: .context("plugin.resume"))
        let suggestions = [global, launcher, activeLauncher, story, resume]

        #expect(
            visibleSuggestions(
                suggestions,
                hasProject: true,
                contextID: ChatContext.defaultChat.id
            ).map(\.id) == ["global", "launcher", "active-launcher"]
        )
        #expect(
            visibleSuggestions(
                suggestions,
                hasProject: true,
                contextID: "plugin.story"
            ).map(\.id) == ["global", "active-launcher", "story"]
        )
    }

    @Test("上下文提示词仍遵守项目可见性")
    func contextScopeRespectsProjectVisibility() {
        let suggestion = PromptSuggestion(
            id: "project-story",
            title: "项目故事",
            visibility: .onlyWithProject,
            scope: .context("plugin.story")
        )

        #expect(visibleSuggestions([suggestion], hasProject: true, contextID: "plugin.story").count == 1)
        #expect(visibleSuggestions([suggestion], hasProject: false, contextID: "plugin.story").isEmpty)
    }
}
