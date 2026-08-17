import ProviderLLMVendors
import Foundation
import ProviderLLMManager
import ProviderNetwork

/// Anthropic 供应商（迁移自旧 LLMProviderAnthropicPlugin）。
@MainActor
public final class AnthropicProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "anthropic",
                displayName: "Anthropic",
                description: "Claude AI by Anthropic",
                defaultModel: "claude-sonnet-4-20250514",
                models: [
                    LLMModelInfo(id: "claude-sonnet-4-20250514", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "claude-opus-4-20250514", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "claude-3-5-sonnet-20241022", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "claude-3-5-sonnet-20240620", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "claude-3-opus-20240229", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "claude-3-sonnet-20240229", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "claude-3-haiku-20240307", contextWindowSize: 200_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://www.anthropic.com/")!,
                apiFormat: .anthropic,
                apiKeyStorageKey: "DevAssistant_ApiKey_Anthropic"
            ),
            apiService: apiService
        )
    }

    /// 便捷初始化：注入 `NetworkProviding` 以支持 HTTP 交换记录。
    public convenience init(networkProvider: (any NetworkProviding)?) {
        let apiService = VendorAPIService(networkProvider: networkProvider)
        self.init(apiService: apiService)
    }

    public override var anthropicConfiguration: AnthropicCompatibleProviderConfiguration? {
        AnthropicCompatibleProviderConfiguration(
            baseURL: "https://api.anthropic.com/v1/messages"
        )
    }
}
