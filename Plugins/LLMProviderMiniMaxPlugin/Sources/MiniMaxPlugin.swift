import LumiCoreKit

public enum MiniMaxPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.minimax",
        displayName: LumiPluginLocalization.string("MiniMax", bundle: .module),
        description: LumiPluginLocalization.string(
            "Contributes MiniMax TokenPlan models, video generation tools, and MiniMax-specific chat error renderers.",
            bundle: .module
        ),
        order: 104
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [MiniMaxTokenPlanProvider()]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [MiniMaxVideoTool()]
    }

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        ProviderRenderKindManager.shared.registerProviderPrefix(
            "minimax-",
            for: MiniMaxTokenPlanProvider.info.id
        )
        return [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }
}
