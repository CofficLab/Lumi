import LumiKernel
import os

public enum CodexLumiPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.llm-provider.codex")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.codex",
        displayName: LumiPluginLocalization.string("Codex CLI", bundle: .module),
        description: LumiPluginLocalization.string("OpenAI models through the Codex CLI.", bundle: .module),
        order: 105,
        category: .llmProvider,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "terminal",
    )

    @MainActor
    public static func llmProviders(context: any LumiLLMProviderSettingsContributing) -> [any LumiLLMProvider] {
        [CodexLumiProvider()]
    }

    @MainActor
    public static func llmProviderSettingsViews(context: any LumiLLMProviderSettingsContributing) -> [LumiLLMProviderSettingsViewItem] {
        [
            LumiLLMProviderSettingsViewItem(providerID: "codex") { provider in
                CodexLocalProviderSettingsView(provider: provider)
            },
        ]
    }
}
