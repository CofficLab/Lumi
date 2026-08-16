import ProviderLLMVendors
import Foundation
import ProviderLLMManager

/// Kimi Code 供应商（OpenAI 兼容协议，迁移自旧 LLMProviderKimiCodePlugin 的
/// `KimiCodeOpenAIProvider`）。
@MainActor
public final class KimiCodeProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "kimi-code-openai",
                displayName: "Kimi Code (OpenAI)",
                description: "Kimi Code API via OpenAI-compatible endpoint.",
                defaultModel: "k3",
                models: [
                    LLMModelInfo(id: "k3", displayName: "Kimi K3", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "k3-256k", displayName: "Kimi K3 256K", contextWindowSize: 256_000, supportsVision: true),
                    LLMModelInfo(id: "kimi-for-coding", displayName: "Kimi K2.7 Code", contextWindowSize: 256_000, supportsVision: true),
                    LLMModelInfo(id: "kimi-for-coding-highspeed", displayName: "Kimi K2.7 Code High Speed", contextWindowSize: 256_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://www.moonshot.cn/")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_KimiCode"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.kimi.com/coding/v1/chat/completions"
        )
    }
}
