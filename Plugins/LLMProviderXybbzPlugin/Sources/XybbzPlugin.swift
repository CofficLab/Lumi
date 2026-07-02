import LumiCoreKit
import os

public enum XybbzPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider.xybbz")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.xybbz",
        displayName: LumiPluginLocalization.string("Xybbz", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Xybbz models to Lumi Chat.", bundle: .module),
        order: 103
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [XybbzProvider()]
    }
}
