import KitLLM
import Foundation
import ProviderLLMManager

/// Xybbz 供应商（迁移自旧 LLMProviderXybbzPlugin）。
@MainActor
public final class XybbzProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "xybbz",
                displayName: "Xybbz",
                description: "AI API Gateway by xybbz",
                defaultModel: "gpt-5.5",
                models: [
                    LLMModelInfo(id: "gpt-5.5", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.4", contextWindowSize: 1_000_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://xybbz.xyz")!,
                providerType: .relay,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_Xybbz"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://sub2api.xybbz.xyz/v1/chat/completions"
        )
    }

}
