import LumiCoreKit
import os

public enum StepFunPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.stepfun")
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.stepfun",
        displayName: LumiPluginLocalization.string("StepFun StepPlan", bundle: .module),
        description: LumiPluginLocalization.string("Contributes StepFun StepPlan models to Lumi Chat.", bundle: .module),
        order: 93
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [StepFunProvider()]
    }

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        ProviderRenderKindManager.shared.registerProviderPrefix("stepfun-", for: StepFunProvider.info.id)
        return [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }

    @MainActor
    public static func subAgents(context: LumiPluginContext) -> [LumiSubAgentDefinition] {
        [
            LumiSubAgentDefinition(
                id: "git-commit-writer",
                displayName: "Git Commit Writer",
                description: "Analyze git changes and create a commit. Pass what you want committed as the task.",
                providerID: StepFunProvider.info.id,
                modelID: "step-3.7-flash",
                systemPrompt: """
                    You are a git commit assistant. Steps:
                    1. Call git_status to check working tree state.
                    2. Call git_diff to review changes.
                    3. Generate a Conventional Commits message.
                    4. Call git_add to stage, then git_commit to commit.
                    If nothing to commit, say so. Don't retry more than twice on failure.
                    """,
                requiredTags: [.git],
                excludedTags: [.destructive],
                excludedToolNames: ["git_push"],
                maxTurns: 8,
                iconName: "checkmark.seal"
            )
        ]
    }
}