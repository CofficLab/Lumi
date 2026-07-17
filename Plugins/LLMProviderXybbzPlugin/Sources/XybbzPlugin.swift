import LumiLLMProviderSupport
import LumiCoreKit
import os

public enum XybbzPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider.xybbz")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.xybbz",
        displayName: LumiPluginLocalization.string("Xybbz", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Xybbz models to Lumi Chat.", bundle: .module),
        order: 103,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderXybbzPlugin", directory: core.storage.pluginDataDirectory(for: "LLMProviderXybbzPlugin"))
        }
        return [XybbzProvider()]
    }
}
