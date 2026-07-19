import LLMKit
import LumiKernel
import LumiKernel

public enum SublyxPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.sublyx",
        displayName: LumiPluginLocalization.string("Sublyx", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Sublyx GPT models to Lumi Chat.", bundle: .module),
        order: 104,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: any LumiLLMProviderSettingsContributing) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderSublyxPlugin", directory: core.storage.pluginDataDirectory(for: "LLMProviderSublyxPlugin"))
        }
        return [SublyxProvider()]
    }

    @MainActor
    public static func messageRenderers(context: any LumiChatContributionProviding) -> [LumiMessageRendererItem] {
        ProviderRenderKindManager.shared.registerProviderPrefix("sublyx-", for: SublyxProvider.info.id)
        return [
            SublyxApiKeyMissingRenderer.item,
            SublyxHttpErrorRenderer.item,
            SublyxRequestFailedRenderer.item,
        ]
    }
}
