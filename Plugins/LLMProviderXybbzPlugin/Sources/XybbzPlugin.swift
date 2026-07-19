import LLMKit
import LumiKernel
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
    public static func llmProviders(lumiCore: any LumiCoreAccessing) -> [any LumiLLMProvider] {
        AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderXybbzPlugin", directory: lumiCore.storage.pluginDataDirectory(for: "LLMProviderXybbzPlugin"))
        return [XybbzProvider()]
    }
}
