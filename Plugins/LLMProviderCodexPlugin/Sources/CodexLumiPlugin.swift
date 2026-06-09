import LumiCoreKit

public enum CodexLumiPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "terminal"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.codex",
        displayName: "Codex CLI",
        description: "OpenAI models through the Codex CLI.",
        order: 105
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [CodexLumiProvider()]
    }
}
