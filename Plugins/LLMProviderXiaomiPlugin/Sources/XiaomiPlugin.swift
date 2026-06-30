import LumiCoreKit

public enum XiaomiPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.xiaomi",
        displayName: LumiPluginLocalization.string("Xiaomi", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Xiaomi TokenPlan and Xiaomi API (OpenAI-compatible) models to Lumi Chat.", bundle: .module),
        order: 102
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [XiaomiProvider(), XiaomiAPIProvider()]
    }

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        ProviderRenderKindManager.shared.registerProviderPrefix("xiaomi-", for: XiaomiProvider.info.id)
        return [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }
}
