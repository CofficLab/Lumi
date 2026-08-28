import KitLLM
import Foundation
import ProviderLLMManager

/// DeepSeek 供应商（OpenAI 兼容协议，迁移自旧 LLMProviderDeepSeekPlugin 的
/// `DeepSeekOpenAIProvider`）。
@MainActor
public final class DeepSeekProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "deepseek",
                displayName: "DeepSeek",
                description: "DeepSeek AI",
                defaultModel: "deepseek-v4-flash",
                models: [
                    LLMModelInfo(id: "deepseek-v4-flash", contextWindowSize: 1_000_000, supportsVision: false),
                    LLMModelInfo(id: "deepseek-v4-pro", contextWindowSize: 1_000_000, supportsVision: false),
                ],
                websiteURL: URL(string: "https://www.deepseek.com/")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_DeepSeek"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.deepseek.com/v1/chat/completions"
        )
    }

}
