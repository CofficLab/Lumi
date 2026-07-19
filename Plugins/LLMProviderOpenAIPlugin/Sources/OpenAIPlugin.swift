import LLMKit
import LumiCoreKit
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
    public static func llmProviders(context: any LumiLLMProviderSettingsContributing) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderOpenAIPlugin", directory: core.storage.pluginDataDirectory(for: "LLMProviderOpenAIPlugin"))
        }
        return [OpenAIProvider()]
    }
}
