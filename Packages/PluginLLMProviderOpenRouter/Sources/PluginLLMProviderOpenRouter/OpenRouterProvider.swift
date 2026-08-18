import KitLLM
import Foundation
import ProviderLLMManager

/// OpenRouter 供应商（迁移自旧 LLMProviderOpenRouterPlugin）。
@MainActor
public final class OpenRouterProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "openrouter",
                displayName: "OpenRouter",
                description: "Multi-Provider LLM Router",
                defaultModel: "alibaba/qwen3.5-397b",
                models: [
                    LLMModelInfo(id: "alibaba/qwen3.5-397b", contextWindowSize: 131_072, supportsVision: false),
                    LLMModelInfo(id: "anthropic/claude-haiku-4-5-20251001", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "anthropic/claude-opus-4-5-20251101", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "anthropic/claude-sonnet-4-5-20250929", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "bytedance-seed/seedream-4.5", contextWindowSize: 32_000, supportsVision: true),
                    LLMModelInfo(id: "deepseek/deepseek-v3.1", contextWindowSize: 1_000_000, supportsVision: false),
                    LLMModelInfo(id: "google/gemma-3-27b-it:free", contextWindowSize: 131_072, supportsVision: true),
                    LLMModelInfo(id: "google/gemini-pro-2.5", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "meta-llama/llama-3.3-70b-instruct", contextWindowSize: 131_072, supportsVision: false),
                    LLMModelInfo(id: "minimax/minimax-m2.1", contextWindowSize: 1_000_000, supportsVision: false),
                    LLMModelInfo(id: "minimax/minimax-m2.5:free", contextWindowSize: 204_800, supportsVision: false),
                    LLMModelInfo(id: "nvidia/nemotron-3-super-120b-a12b:free", contextWindowSize: 131_072, supportsVision: false),
                    LLMModelInfo(id: "openai/gpt-4o", contextWindowSize: 128_000, supportsVision: true),
                    LLMModelInfo(id: "openai/gpt-5", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "openai/gpt-5-mini", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "openai/gpt-oss-20b:free", contextWindowSize: 131_072, supportsVision: false),
                    LLMModelInfo(id: "qwen/qwen3.6-plus", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "stepfun/step-3.5-flash:free", contextWindowSize: 256_000, supportsVision: true),
                    LLMModelInfo(id: "z-ai/glm-4.5-air:free", contextWindowSize: 131_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://openrouter.ai/")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_OpenRouter"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://openrouter.ai/api/v1/chat/completions"
        )
    }

}
