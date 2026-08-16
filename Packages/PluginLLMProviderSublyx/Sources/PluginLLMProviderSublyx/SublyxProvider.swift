import ProviderLLMVendors
import Foundation
import ProviderLLMManager

/// Sublyx 供应商（迁移自旧 LLMProviderSublyxPlugin 的 `SublyxProvider`）。
@MainActor
public final class SublyxProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "sublyx",
                displayName: "Sublyx",
                description: "GPT API Gateway by Sublyx",
                defaultModel: "gpt-5.5",
                models: [
                    LLMModelInfo(id: "gpt-5.5", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.4", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.4-mini", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-4o", contextWindowSize: 128_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-4.1", contextWindowSize: 1_000_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://api.sublyx.org/")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_Sublyx"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.sublyx.org/v1/chat/completions"
        )
    }
}
