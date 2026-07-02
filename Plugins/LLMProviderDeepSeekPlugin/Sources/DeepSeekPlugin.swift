import LumiCoreKit
import os

public enum DeepSeekPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider.deepseek")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.deepseek",
        displayName: LumiPluginLocalization.string("DeepSeek", bundle: .module),
        description: LumiPluginLocalization.string("Contributes DeepSeek models to Lumi Chat.", bundle: .module),
        order: 92
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [DeepSeekProvider()]
    }
}
