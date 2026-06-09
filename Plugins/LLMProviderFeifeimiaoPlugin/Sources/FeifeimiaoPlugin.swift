import LumiCoreKit
import LumiLLMProviderSupport

public enum FeifeimiaoPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.feifeimiao",
        displayName: "Feifeimiao",
        description: "Contributes Feifeimiao models to Lumi Chat.",
        order: 93
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [FeifeimiaoProvider()]
    }
}

public final class FeifeimiaoProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "feifeimiao",
            displayName: "Feifeimiao",
            description: "LLM API by feifeimiao",
            defaultModel: "gpt-5.5",
            availableModels: [
            "gpt-5.5",
            "gpt-5.4",
            "gpt-5.4-mini",
            "gpt-5.3",
            "gpt-5.2"
            ]
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_Feifeimiao"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://api.feifeimiao.top/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
        )
    }
}
