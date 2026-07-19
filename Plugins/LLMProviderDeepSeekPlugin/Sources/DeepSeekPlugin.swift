import LLMKit
import LumiKernel
import LumiKernel
import os

public enum DeepSeekPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider.deepseek")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.deepseek",
        displayName: LumiPluginLocalization.string("DeepSeek", bundle: .module),
        description: LumiPluginLocalization.string("Contributes DeepSeek models to Lumi Chat.", bundle: .module),
        order: 92,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: any LumiLLMProviderSettingsContributing) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderDeepSeekPlugin", directory: core.storage.pluginDataDirectory(for: "LLMProviderDeepSeekPlugin"))
        }
        return [DeepSeekProvider()]
    }
}
