import LLMKit
import LumiKernel
import LumiKernel
import os

public enum MegaLLMPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider.megallm")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.megallm",
        displayName: LumiPluginLocalization.string("MegaLLM", bundle: .module),
        description: LumiPluginLocalization.string("Contributes MegaLLM models to Lumi Chat.", bundle: .module),
        order: 99,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: any LumiLLMProviderSettingsContributing) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderMegaLLMPlugin", directory: core.storage.pluginDataDirectory(for: "LLMProviderMegaLLMPlugin"))
        }
        return [MegaLLMProvider()]
    }
}
