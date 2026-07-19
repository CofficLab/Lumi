import LLMKit
import LumiCoreKit
import LumiCoreKit

public enum FlyMuxPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.flymux",
        displayName: LumiPluginLocalization.string("FlyMux", bundle: .module),
        description: LumiPluginLocalization.string("Contributes FlyMux models to Lumi Chat.", bundle: .module),
        order: 94,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: any LumiLLMProviderSettingsContributing) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderFlyMuxPlugin", directory: core.storage.pluginDataDirectory(for: "LLMProviderFlyMuxPlugin"))
        }
        return [FlyMuxProvider()]
    }
}
