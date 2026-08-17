import ProviderLLMVendors
import Foundation
import ProviderLLMManager
import ProviderNetwork

/// LPgpt 供应商（迁移自旧 LLMProviderLPgptPlugin）。
@MainActor
public final class LPgptProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "lpgpt",
                displayName: "LPgpt",
                description: "Free LLM Gateway by lpgpt.us",
                defaultModel: "gpt-5.4",
                models: [
                    LLMModelInfo(id: "gpt-5.4", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5.5", contextWindowSize: 1_000_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://lpgpt.us")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_LPgpt"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://lpgpt.us/v1/chat/completions"
        )
    }

    /// 便捷初始化：注入 `NetworkProviding` 以支持 HTTP 交换记录。
    public convenience init(networkProvider: (any NetworkProviding)?) {
        let apiService = VendorAPIService(networkProvider: networkProvider)
        self.init(apiService: apiService)
    }
}
