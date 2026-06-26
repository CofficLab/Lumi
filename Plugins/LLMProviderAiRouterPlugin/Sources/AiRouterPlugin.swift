import LumiCoreKit

public enum AiRouterPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.airouter",
        displayName: LumiPluginLocalization.string("AiRouter", bundle: .module),
        description: LumiPluginLocalization.string("Contributes AiRouter models to Lumi Chat.", bundle: .module),
        order: 91
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [AiRouterProvider()]
    }
}
