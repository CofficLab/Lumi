import LumiCoreKit

public enum ZhipuPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.zhipu",
        displayName: LumiPluginLocalization.string("智谱", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Zhipu GLM models and Zhipu-specific chat error renderers.", bundle: .module),
        order: 110
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
        [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }
}
