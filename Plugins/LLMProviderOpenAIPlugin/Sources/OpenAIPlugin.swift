import LumiCoreKit

public enum OpenAIPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.openai",
        displayName: LumiPluginLocalization.string("OpenAI", bundle: .module),
        description: LumiPluginLocalization.string("Contributes OpenAI GPT models to Lumi Chat.", bundle: .module),
        order: 100,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [OpenAIProvider()]
    }
}
