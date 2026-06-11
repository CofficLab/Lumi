import LumiCoreKit
import LumiLLMProviderSupport

public enum AiRouterPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.airouter",
        displayName: LumiPluginLocalization.string("AiRouter", bundle: .module),
        description: LumiPluginLocalization.string("Contributes AiRouter models to Lumi Chat.", bundle: .module),
        order: 91
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [AiRouterProvider()]
    }
}

public final class AiRouterProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "airouter",
            displayName: LumiPluginLocalization.string("AiRouter", bundle: .module),
            description: LumiPluginLocalization.string("LLM Router by airouter.org", bundle: .module),
            defaultModel: "gpt-5",
            availableModels: [
            "gpt-5.1-codex-max",
            "gpt-5.2-codex",
            "gpt-5.4-mini",
            "gpt-5",
            "gpt-5.1-codex-mini",
            "gpt-5.2",
            "gpt-5.3-codex",
            "gpt-5.4",
            "gpt-5-codex",
            "gpt-5.1",
            "gpt-5.1-codex"
            ]
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_AiRouter"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://api.airouter.org/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
        )
    }
}
