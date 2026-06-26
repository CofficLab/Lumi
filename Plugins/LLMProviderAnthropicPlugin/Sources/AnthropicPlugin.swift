import LumiCoreKit

public enum AnthropicPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.anthropic",
        displayName: LumiPluginLocalization.string("Anthropic", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Anthropic Claude models to Lumi Chat.", bundle: .module),
        order: 104
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [AnthropicProvider()]
    }
}
