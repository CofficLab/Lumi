import LumiCoreKit
import os

public enum OpenRouterPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider.openrouter")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.openrouter",
        displayName: LumiPluginLocalization.string("OpenRouter", bundle: .module),
        description: LumiPluginLocalization.string("Contributes OpenRouter models to Lumi Chat.", bundle: .module),
        order: 101
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [OpenRouterProvider()]
    }
}
