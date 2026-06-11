import LumiCoreKit

@available(macOS 14.0, *)
public enum MLXLumiPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "desktopcomputer"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.mlx",
        displayName: String(localized: "MLX", bundle: .module),
        description: String(localized: "Local MLX models for offline chat.", bundle: .module),
        order: 95
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [MLXLumiProvider()]
    }
}
