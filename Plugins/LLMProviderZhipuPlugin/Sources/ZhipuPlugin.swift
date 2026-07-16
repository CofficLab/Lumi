import LumiCoreKit

public enum ZhipuPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.zhipu",
        displayName: LumiPluginLocalization.string("智谱 Coding Plan", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Zhipu GLM models and Zhipu-specific chat error renderers.", bundle: .module),
        order: 110,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [
            ZhipuProvider(),
            ZhipuAPIProvider()
        ]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.isChatSectionVisible,
              context.activeProviderID == ZhipuProvider.info.id
        else {
            return []
        }

        return [
            LumiStatusBarItem(
                id: "\(info.id).quota",
                title: LumiPluginLocalization.string("Zhipu GLM Quota", bundle: .module),
                systemImage: "chart.bar.fill",
                placement: .trailing,
                statusBarView: {
                    StatusBarView()
                }
            )
        ]
    }

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        ProviderRenderKindManager.shared.registerProviderPrefix("zhipu-", for: ZhipuProvider.info.id)
        return [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }
}
