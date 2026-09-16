import ProviderPromptSuggestion
import Testing
@testable import PluginMessageListEmpty

@Test @MainActor func promptSuggestionsRespectProjectVisibilityAndLauncherScope() {
    let suggestions = [
        PromptSuggestion(id: "global", title: "Global"),
        PromptSuggestion(id: "project", title: "Project", visibility: .onlyWithProject),
        PromptSuggestion(id: "no-project", title: "No project", visibility: .onlyWithoutProject),
        PromptSuggestion(id: "launcher", title: "Launcher", scope: .launcher),
        PromptSuggestion(id: "context", title: "Context", scope: .context("workflow")),
        PromptSuggestion(id: "launcher-context", title: "Launcher context", scope: .launcherAndContext("workflow")),
    ]

    let noProjectLauncher = visibleSuggestions(suggestions, hasProject: false)
    let defaultChat = visibleSuggestions(suggestions, hasProject: true, contextID: "com.coffic.lumi.chat.default")
    let workflow = visibleSuggestions(suggestions, hasProject: true, contextID: "workflow")
    let unrelatedContext = visibleSuggestions(suggestions, hasProject: true, contextID: "other")

    #expect(Set(noProjectLauncher.map(\.id)) == ["global", "no-project", "launcher", "launcher-context"])
    #expect(Set(defaultChat.map(\.id)) == ["global", "project", "launcher", "launcher-context"])
    #expect(Set(workflow.map(\.id)) == ["global", "project", "context", "launcher-context"])
    #expect(Set(unrelatedContext.map(\.id)) == ["global", "project"])
}

@Test @MainActor func promptSuggestionVisibilityAndScopeMustBothMatch() {
    let suggestions = [
        PromptSuggestion(id: "project-context", title: "Project context", visibility: .onlyWithProject, scope: .context("workflow")),
        PromptSuggestion(id: "no-project-context", title: "No project context", visibility: .onlyWithoutProject, scope: .context("workflow")),
    ]

    #expect(visibleSuggestions(suggestions, hasProject: false, contextID: "workflow").map(\.id) == ["no-project-context"])
    #expect(visibleSuggestions(suggestions, hasProject: true, contextID: "workflow").map(\.id) == ["project-context"])
    #expect(visibleSuggestions(suggestions, hasProject: true, contextID: "other").isEmpty)
}
