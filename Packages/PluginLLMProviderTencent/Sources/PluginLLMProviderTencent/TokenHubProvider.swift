import Foundation
import KitLLM
import ProviderLLMManager

/// 腾讯云 TokenHub 供应商（OpenAI Chat Completions 兼容协议）。
@MainActor
public final class TokenHubProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "tencent",
                displayName: "腾讯云",
                description: "Tencent Cloud TokenHub",
                defaultModel: "hy4-preview",
                models: [
                    LLMModelInfo(id: "hy4-preview"),
                ],
                websiteURL: URL(string: "https://tokenhub.tencentmaas.com/"),
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_Tencent"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://tokenhub.tencentmaas.com/v1/chat/completions"
        )
    }
}
