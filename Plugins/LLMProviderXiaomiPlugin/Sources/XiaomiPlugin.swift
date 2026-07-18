import LLMKit
import LumiCoreKit
import LumiCoreKit

public enum XiaomiPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.xiaomi",
        displayName: LumiPluginLocalization.string("Xiaomi", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Xiaomi TokenPlan and Xiaomi API (OpenAI-compatible) models to Lumi Chat.", bundle: .module),
        order: 102,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        if let core = context.lumiCore {
            AvailabilityDiskCacheDirectoryResolver.set(pluginName: "LLMProviderXiaomiPlugin", directory: core.storage.pluginDataDirectory(for: "LLMProviderXiaomiPlugin"))
        }
        return [XiaomiProvider(), XiaomiAPIProvider()]
    }

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        ProviderRenderKindManager.shared.registerProviderPrefix("xiaomi-", for: XiaomiProvider.info.id)
        return [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }
}
