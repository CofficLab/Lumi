import ProviderLLMVendors
import Foundation
import ProviderLLMManager

/// Feifeimiao 供应商（迁移自旧 LLMProviderFeifeimiaoPlugin）。
@MainActor
public final class FeifeimiaoProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "feifeimiao",
                displayName: "Feifeimiao",
                description: "LLM API by feifeimiao",
                defaultModel: "gpt-5.5",
                models: [
                    LLMModelInfo(id: "gpt-5.5", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.4", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.4-mini", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.3", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.2", contextWindowSize: 400_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://feifeimiao.top")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_Feifeimiao"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.feifeimiao.top/v1/chat/completions"
        )
    }
}
