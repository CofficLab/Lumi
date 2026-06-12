import LumiCoreKit
import LumiLLMProviderSupport

public enum OpenRouterPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.openrouter",
        displayName: LumiPluginLocalization.string("OpenRouter", bundle: .module),
        description: LumiPluginLocalization.string("Contributes OpenRouter models to Lumi Chat.", bundle: .module),
        order: 101
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [OpenRouterProvider()]
    }
}

public final class OpenRouterProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "openrouter",
            displayName: LumiPluginLocalization.string("OpenRouter", bundle: .module),
            description: LumiPluginLocalization.string("Multi-Provider LLM Router", bundle: .module),
            defaultModel: "alibaba/qwen3.5-397b",
            availableModels: [
            "alibaba/qwen3.5-397b",
            "anthropic/claude-haiku-4-5-20251001",
            "anthropic/claude-opus-4-5-20251101",
            "anthropic/claude-sonnet-4-5-20250929",
            "bytedance-seed/seedream-4.5",
            "deepseek/deepseek-v3.1",
            "google/gemma-3-27b-it:free",
            "google/gemini-pro-2.5",
            "meta-llama/llama-3.3-70b-instruct",
            "minimax/minimax-m2.1",
            "minimax/minimax-m2.5:free",
            "nvidia/nemotron-3-super-120b-a12b:free",
            "openai/gpt-4o",
            "openai/gpt-5",
            "openai/gpt-5-mini",
            "openai/gpt-oss-20b:free",
            "qwen/qwen3.6-plus",
            "stepfun/step-3.5-flash:free",
            "z-ai/glm-4.5-air:free"
            ]
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_OpenRouter"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://openrouter.ai/api/v1/chat/completions",
            additionalHeaders: ["HTTP-Referer": "Lumi", "X-Title": "Lumi"],
            includeUsageInStreamOptions: false,
            returnsEmptyChunkWhenNoDelta: true,
            acceptsFunctionScopedToolCallID: true
        )
        )
    }
}
