import LumiCoreKit

public enum HappyCodePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.happycode",
        displayName: LumiPluginLocalization.string("HappyCode", bundle: .module),
        description: LumiPluginLocalization.string("Contributes HappyCode models to Lumi Chat.", bundle: .module),
        order: 96
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [HappyCodeProvider()]
    }
}
