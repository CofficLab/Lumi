import LumiCoreKit

public enum CodexLumiPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "terminal"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.codex",
        displayName: LumiPluginLocalization.string("Codex CLI", bundle: .module),
        description: LumiPluginLocalization.string("OpenAI models through the Codex CLI.", bundle: .module),
        order: 105
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [CodexLumiProvider()]
    }

    @MainActor
    public static func llmProviderSettingsViews(context: LumiPluginContext) -> [LumiLLMProviderSettingsViewItem] {
        [
            LumiLLMProviderSettingsViewItem(providerID: "codex") { provider in
                CodexLocalProviderSettingsView(provider: provider)
            },
        ]
    }
}
