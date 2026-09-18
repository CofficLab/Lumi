import KitLLM
import Foundation
import ProviderLLMManager

/// AiRouter 供应商（迁移自旧 LLMProviderAiRouterPlugin）。
@MainActor
public final class AiRouterProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "airouter",
                displayName: "AiRouter",
                description: "LLM Router by airouter.org",
                defaultModel: "gpt-5",
                models: [
                    LLMModelInfo(id: "gpt-5.1-codex-max", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.2-codex", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.4-mini", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.1-codex-mini", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.2", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.3-codex", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.4", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5-codex", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.1", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.1-codex", contextWindowSize: 400_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://airouter.org")!,
                providerType: .relay,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_AiRouter"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.airouter.org/v1/chat/completions"
        )
    }

}
