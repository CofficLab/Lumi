import LumiCoreKit

public enum FlyMuxPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.flymux",
        displayName: LumiPluginLocalization.string("FlyMux", bundle: .module),
        description: LumiPluginLocalization.string("Contributes FlyMux models to Lumi Chat.", bundle: .module),
        order: 94
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [FlyMuxProvider()]
    }
}
