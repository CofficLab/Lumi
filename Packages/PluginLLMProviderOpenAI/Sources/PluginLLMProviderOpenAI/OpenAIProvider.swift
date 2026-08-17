import ProviderLLMVendors
import Foundation
import ProviderLLMManager
import ProviderNetwork

/// OpenAI 供应商（迁移自旧 LLMProviderOpenAIPlugin）。
@MainActor
public final class OpenAIProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "openai",
                displayName: "OpenAI",
                description: "GPT by OpenAI",
                defaultModel: "gpt-4o",
                models: [
                    LLMModelInfo(id: "gpt-5", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-5-mini", contextWindowSize: 400_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-4o", contextWindowSize: 128_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-4o-mini", contextWindowSize: 128_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-4-turbo", contextWindowSize: 128_000, supportsVision: true),
                    LLMModelInfo(id: "gpt-4", contextWindowSize: 8_192, supportsVision: false),
                    LLMModelInfo(id: "gpt-3.5-turbo", contextWindowSize: 16_385, supportsVision: false),
                ],
                websiteURL: URL(string: "https://openai.com/")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_OpenAI"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.openai.com/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
    }

    /// 便捷初始化：注入 `NetworkProviding` 以支持 HTTP 交换记录。
    public convenience init(networkProvider: (any NetworkProviding)?) {
        let apiService = VendorAPIService(networkProvider: networkProvider)
        self.init(apiService: apiService)
    }
}
