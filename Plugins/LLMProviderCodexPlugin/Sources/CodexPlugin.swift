import LumiKernel
import os

public enum CodexPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider.codex")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.codex",
        displayName: LumiPluginLocalization.string("Codex", bundle: .module),
        description: LumiPluginLocalization.string("Contributes Codex models to Lumi Chat.", bundle: .module),
        order: 105,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "sparkles",
    )

    @MainActor
    public static func llmProviders(lumiCore: any LumiCoreAccessing) -> [any LumiLLMProvider] {
        return [CodexProvider()]
    }
}
