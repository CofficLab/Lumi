import LumiCoreKit

public enum MegaLLMPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.megallm",
        displayName: LumiPluginLocalization.string("MegaLLM", bundle: .module),
        description: LumiPluginLocalization.string("Contributes MegaLLM models to Lumi Chat.", bundle: .module),
        order: 99
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [MegaLLMProvider()]
    }
}
