import LumiCoreKit

public enum LPgptPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.lpgpt",
        displayName: LumiPluginLocalization.string("LPgpt", bundle: .module),
        description: LumiPluginLocalization.string("Contributes LPgpt models to Lumi Chat.", bundle: .module),
        order: 98,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [LPgptProvider()]
    }
}
