import LumiLLMProviderSupport
import LumiCoreKit

public enum MiniMaxPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.minimax",
        displayName: LumiPluginLocalization.string("MiniMax", bundle: .module),
        description: LumiPluginLocalization.string(
            "Contributes MiniMax TokenPlan models, video generation tools, and MiniMax-specific chat error renderers.",
            bundle: .module
        ),
        order: 104,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderMiniMax", directory: core.storage.pluginDataDirectory(for: "LLMProviderMiniMax"))
        }
        return [MiniMaxTokenPlanProvider()]
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
