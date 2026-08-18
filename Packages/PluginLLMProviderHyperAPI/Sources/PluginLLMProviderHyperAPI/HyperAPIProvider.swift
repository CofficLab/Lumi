import KitLLM
import Foundation
import ProviderLLMManager

/// HyperAPI 供应商（迁移自旧 LLMProviderHyperAPIPlugin）。
@MainActor
public final class HyperAPIProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "hyperapi",
                displayName: "HyperAPI",
                description: "LLM Router by hyperapi.cc",
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
                websiteURL: URL(string: "https://hyperapi.cc")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_HyperAPI"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://hyperapi.cc/v1/chat/completions"
        )
    }

}
