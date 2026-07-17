import LumiLLMProviderSupportimport LumiCoreKit

public enum HappyCodePlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.happycode",
        displayName: LumiPluginLocalization.string("HappyCode", bundle: .module),
        description: LumiPluginLocalization.string("Contributes HappyCode models to Lumi Chat.", bundle: .module),
        order: 96,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderHappyCodePlugin", directory: core.pluginDataDirectory(for: "LLMProviderHappyCodePlugin"))
        }
        return [HappyCodeProvider()]
    }
}
