import LumiCoreKit

public enum AliyunPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.aliyun",
        displayName: "阿里云 CodingPlan",
        description: "Contributes Aliyun CodingPlan models and Aliyun-specific chat error renderers.",
        order: 105
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [AliyunProvider()]
    }

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }
}
