import LumiCoreKit

public enum SublyxPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.sublyx",
        displayName: LumiPluginLocalization.string("Sublyx", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Sublyx GPT models to Lumi Chat.", bundle: .module),
        order: 104
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [SublyxProvider()]
    }

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        [SublyxApiKeyMissingRenderer.item]
    }
}
