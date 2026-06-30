import LumiCoreKit
import os

public enum StepFunPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.stepfun")
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.stepfun",
        displayName: LumiPluginLocalization.string("StepFun StepPlan", bundle: .module),
        description: LumiPluginLocalization.string("Contributes StepFun StepPlan models to Lumi Chat.", bundle: .module),
        order: 93
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [StepFunProvider()]
    }

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        ProviderRenderKindManager.shared.registerProviderPrefix("stepfun-", for: StepFunProvider.info.id)
        return [
            ApiKeyMissingRenderer.item,
            Http401Renderer.item,
            Http403Renderer.item,
            HttpErrorRenderer.item,
            RequestFailedRenderer.item,
        ]
    }
}
