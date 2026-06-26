import LumiCoreKit

public enum HyperAPIPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.hyperapi",
        displayName: LumiPluginLocalization.string("HyperAPI", bundle: .module),
        description: LumiPluginLocalization.string("Contributes HyperAPI models to Lumi Chat.", bundle: .module),
        order: 97
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [HyperAPIProvider()]
    }
}
