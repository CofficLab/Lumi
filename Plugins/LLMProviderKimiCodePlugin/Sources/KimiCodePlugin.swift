import LumiLLMProviderSupport
import LumiCoreKit
import os

public enum KimiCodePlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider.kimi-code")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.kimi-code",
        displayName: LumiPluginLocalization.string("Kimi Code", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Kimi Code models to Lumi Chat.", bundle: .module),
        order: 103,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            let directory = core.storage.pluginDataDirectory(for: "LLMProviderKimiCodePlugin")
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderKimiCodePlugin-OpenAI", directory: directory)
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderKimiCodePlugin-Anthropic", directory: directory)
        }
        return [
            KimiCodeOpenAIProvider(),
            KimiCodeAnthropicProvider()
        ]
    }
}