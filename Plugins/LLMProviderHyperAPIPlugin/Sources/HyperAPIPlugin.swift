import LumiCoreKit

public enum HyperAPIPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.hyperapi",
        displayName: LumiPluginLocalization.string("HyperAPI", bundle: .module),
        description: LumiPluginLocalization.string("Contributes HyperAPI models to Lumi Chat.", bundle: .module),
        order: 97,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [HyperAPIProvider()]
    }
}
