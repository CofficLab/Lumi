import KitLLM
import Foundation
import ProviderLLMManager

/// FlyMux 供应商（迁移自旧 LLMProviderFlyMuxPlugin）。
@MainActor
public final class FlyMuxProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "flymux",
                displayName: "FlyMux",
                description: "LLM API Gateway by FlyMux",
                defaultModel: "gpt-5.5",
                models: [
                    LLMModelInfo(id: "gpt-5.5", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.4", contextWindowSize: 1_000_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://flymux.ai")!,
                providerType: .relay,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_FlyMux"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.flymux.ai/v1/chat/completions"
        )
    }

}
