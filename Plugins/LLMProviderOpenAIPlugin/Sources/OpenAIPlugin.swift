import LumiCoreKit

public enum OpenAIPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.openai",
        displayName: "OpenAI",
        description: "Contributes OpenAI GPT models to Lumi Chat.",
        order: 100
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [OpenAIProvider()]
    }
}
