import LumiCoreKit

public enum LPgptPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.lpgpt",
        displayName: LumiPluginLocalization.string("LPgpt", bundle: .module),
        description: LumiPluginLocalization.string("Contributes LPgpt models to Lumi Chat.", bundle: .module),
        order: 98
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [LPgptProvider()]
    }
}
