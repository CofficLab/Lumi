import LumiCoreKit

public enum AliyunPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.aliyun",
        displayName: LumiPluginLocalization.string("阿里云 CodingPlan", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Aliyun CodingPlan and Aliyun TokenPlan models and Aliyun-specific chat error renderers.", bundle: .module),
        order: 105
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [AliyunProvider(), AliyunTokenPlanProvider()]
    }

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        ProviderRenderKindManager.shared.registerProviderPrefix("aliyun-", for: AliyunProvider.info.id)
        return [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }
}
