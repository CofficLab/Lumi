import LumiCoreKit

public enum FeifeimiaoPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.feifeimiao",
        displayName: LumiPluginLocalization.string("Feifeimiao", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Feifeimiao models to Lumi Chat.", bundle: .module),
        order: 93
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [FeifeimiaoProvider()]
    }
}
