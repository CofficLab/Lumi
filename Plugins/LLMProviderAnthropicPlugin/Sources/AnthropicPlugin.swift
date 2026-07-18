import LLMKit
import LumiCoreKit
import LumiCoreKit

public enum AnthropicPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.anthropic",
        displayName: LumiPluginLocalization.string("Anthropic", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Anthropic Claude models to Lumi Chat.", bundle: .module),
        order: 104,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderAnthropicPlugin", directory: core.storage.pluginDataDirectory(for: "LLMProviderAnthropicPlugin"))
        }
        return [AnthropicProvider()]
    }
}
