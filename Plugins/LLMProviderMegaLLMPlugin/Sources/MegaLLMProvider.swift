import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

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
            ],
            contextWindowSizes: [
                "alibaba-qwen3.5-397b": 131_072,
                "claude-haiku-4-5-20251001": 200_000,
                "claude-opus-4-5-20251101": 200_000,
                "claude-opus-4-6": 200_000,
                "claude-sonnet-4-5-20250929": 200_000,
                "claude-sonnet-4-6": 200_000,
                "deepseek-ai/deepseek-v3.1": 1_000_000,
                "grok-4.1-fast-reasoning": 1_000_000,
                "gpt-5-mini": 400_000,
                "gpt-5.3-codex": 400_000,
                "llama3.3-70b-instruct": 131_072,
                "minimaxai/minimax-m2.1": 1_000_000,
                "newclaude-opus-4-6": 200_000
            ],
            modelCapabilities: [
                "alibaba-qwen3.5-397b": .init(supportsVision: false, supportsTools: true),
                "claude-haiku-4-5-20251001": .init(supportsVision: true, supportsTools: true),
                "claude-opus-4-5-20251101": .init(supportsVision: true, supportsTools: true),
                "claude-opus-4-6": .init(supportsVision: true, supportsTools: true),
                "claude-sonnet-4-5-20250929": .init(supportsVision: true, supportsTools: true),
                "claude-sonnet-4-6": .init(supportsVision: true, supportsTools: true),
                "deepseek-ai/deepseek-v3.1": .init(supportsVision: false, supportsTools: true),
                "grok-4.1-fast-reasoning": .init(supportsVision: true, supportsTools: true),
                "gpt-5-mini": .init(supportsVision: true, supportsTools: true),
                "gpt-5.3-codex": .init(supportsVision: true, supportsTools: true),
                "llama3.3-70b-instruct": .init(supportsVision: false, supportsTools: true),
                "minimaxai/minimax-m2.1": .init(supportsVision: false, supportsTools: true),
                "newclaude-opus-4-6": .init(supportsVision: true, supportsTools: true)
            ],
            websiteURL: URL(string: "https://megallm.io")!
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

    public override func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    public override func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(providerInfo: Self.info)
    }

}
