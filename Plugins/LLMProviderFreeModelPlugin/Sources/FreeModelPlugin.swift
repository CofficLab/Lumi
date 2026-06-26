import LumiCoreKit

public enum FreeModelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.freemodel",
        displayName: LumiPluginLocalization.string("FreeModel", bundle: .module),
        description: LumiPluginLocalization.string("Contributes FreeModel models to Lumi Chat.", bundle: .module),
        order: 95
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [FreeModelProvider()]
    }
}
