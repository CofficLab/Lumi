import ProviderLLMVendors
import Foundation
import ProviderLLMManager
import ProviderNetwork

/// DeepSeek Anthropic 协议变体（迁移自旧 `DeepSeekAnthropicProvider`）。
@MainActor
public final class DeepSeekAnthropicProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "deepseek-anthropic",
                displayName: "DeepSeek (Anthropic Format)",
                description: "DeepSeek AI via Anthropic-compatible endpoint",
                defaultModel: "deepseek-v4-flash",
                models: [
                    LLMModelInfo(id: "deepseek-v4-flash", contextWindowSize: 1_000_000, supportsVision: false),
                    LLMModelInfo(id: "deepseek-v4-pro", contextWindowSize: 1_000_000, supportsVision: false),
                ],
                websiteURL: URL(string: "https://www.deepseek.com/")!,
                apiFormat: .anthropic,
                apiKeyStorageKey: "DevAssistant_ApiKey_DeepSeek"
            ),
            apiService: apiService
        )
    }

    public override var anthropicConfiguration: AnthropicCompatibleProviderConfiguration? {
        AnthropicCompatibleProviderConfiguration(
            baseURL: "https://api.deepseek.com/anthropic"
        )
    }

    /// 便捷初始化：注入 `NetworkProviding` 以支持 HTTP 交换记录。
    public convenience init(networkProvider: (any NetworkProviding)?) {
        let apiService = VendorAPIService(networkProvider: networkProvider)
        self.init(apiService: apiService)
    }
}
