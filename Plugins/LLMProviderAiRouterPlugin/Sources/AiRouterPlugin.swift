import LumiCoreKit

public enum AiRouterPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.airouter",
        displayName: LumiPluginLocalization.string("AiRouter", bundle: .module),
        description: LumiPluginLocalization.string("Contributes AiRouter models to Lumi Chat.", bundle: .module),
        order: 91,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [AiRouterProvider()]
    }
}
