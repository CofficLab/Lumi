import ProviderLLMVendors
import Foundation
import ProviderLLMManager

/// HappyCode 供应商（迁移自旧 LLMProviderHappyCodePlugin）。
@MainActor
public final class HappyCodeProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "happycode",
                displayName: "HappyCode",
                description: "AI API Gateway by HappyCode",
                defaultModel: "gpt-5.5",
                models: [
                    LLMModelInfo(id: "gpt-5.5", contextWindowSize: 1_000_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://happycode.vip")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_HappyCode"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://happycode.vip/v1/chat/completions"
        )
    }
}
