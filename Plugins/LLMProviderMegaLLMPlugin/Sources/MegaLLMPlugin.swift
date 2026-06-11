import LumiCoreKit
import LumiLLMProviderSupport

public enum MegaLLMPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .llmProvider
    public static let iconName = "sparkles"
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.llm-provider.megallm",
        displayName: LumiPluginLocalization.string("MegaLLM", bundle: .module),
        description: LumiPluginLocalization.string("Contributes MegaLLM models to Lumi Chat.", bundle: .module),
        order: 99
    )

    @MainActor
    public static func llmProviders(context: LumiPluginContext) -> [any LumiLLMProvider] {
        [MegaLLMProvider()]
    }
}

public final class MegaLLMProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "megallm",
            displayName: LumiPluginLocalization.string("MegaLLM", bundle: .module),
            description: LumiPluginLocalization.string("MegaLLM AI", bundle: .module),
            defaultModel: "gpt-5-mini",
            availableModels: [
            "alibaba-qwen3.5-397b",
            "claude-haiku-4-5-20251001",
            "claude-opus-4-5-20251101",
            "claude-opus-4-6",
            "claude-sonnet-4-5-20250929",
            "claude-sonnet-4-6",
            "deepseek-ai/deepseek-v3.1",
            "grok-4.1-fast-reasoning",
            "gpt-5-mini",
            "gpt-5.3-codex",
            "llama3.3-70b-instruct",
            "minimaxai/minimax-m2.1",
            "newclaude-opus-4-6"
            ]
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_MegaLLM"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://ai.megallm.io/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: false,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
        )
    }
}
