import LumiLLMProviderSupport
import LumiCoreKit
import os

public enum FeifeimiaoPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider.feifeimiao")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.feifeimiao",
        displayName: LumiPluginLocalization.string("Feifeimiao", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Feifeimiao models to Lumi Chat.", bundle: .module),
        order: 93,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderFeifeimiaoPlugin", directory: core.storage.pluginDataDirectory(for: "LLMProviderFeifeimiaoPlugin"))
        }
        return [FeifeimiaoProvider()]
    }
}
