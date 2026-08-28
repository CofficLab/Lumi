import KitLLM
import Foundation
import ProviderLLMManager

/// MegaLLM 供应商（迁移自旧 LLMProviderMegaLLMPlugin）。
@MainActor
public final class MegaLLMProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "megallm",
                displayName: "MegaLLM",
                description: "MegaLLM AI",
                defaultModel: "gpt-5-mini",
                models: [
                    LLMModelInfo(id: "alibaba-qwen3.5-397b", contextWindowSize: 131_072, supportsVision: false),
                    LLMModelInfo(id: "claude-haiku-4-5-20251001", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "claude-opus-4-5-20251101", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "claude-opus-4-6", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "claude-sonnet-4-5-20250929", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "claude-sonnet-4-6", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "deepseek-ai/deepseek-v3.1", contextWindowSize: 1_000_000, supportsVision: false),
                    LLMModelInfo(id: "grok-4.1-fast-reasoning", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5-mini", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.3-codex", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "llama3.3-70b-instruct", contextWindowSize: 131_072, supportsVision: false),
                    LLMModelInfo(id: "minimaxai/minimax-m2.1", contextWindowSize: 1_000_000, supportsVision: false),
                    LLMModelInfo(id: "newclaude-opus-4-6", contextWindowSize: 200_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://megallm.io")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_MegaLLM"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://ai.megallm.io/v1/chat/completions"
        )
    }

}
