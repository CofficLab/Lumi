import LumiCoreKit
import LumiLLMProviderSupport

public enum DeepSeekPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.deepseek",
        displayName: "DeepSeek",
        description: "Contributes DeepSeek models to Lumi Chat.",
        order: 92
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [DeepSeekProvider()]
    }
}

public final class DeepSeekProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "deepseek",
            displayName: "DeepSeek",
            description: "DeepSeek AI",
            defaultModel: "deepseek-chat",
            availableModels: [
            "deepseek-chat",
            "deepseek-coder"
            ]
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_DeepSeek"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://api.deepseek.com/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: false,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
        )
    }
}
