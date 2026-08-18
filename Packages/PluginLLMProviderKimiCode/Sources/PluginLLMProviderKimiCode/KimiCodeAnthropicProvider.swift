import KitLLM
import Foundation
import ProviderLLMManager

/// Kimi Code Anthropic 协议变体（迁移自旧 `KimiCodeAnthropicProvider`）。
@MainActor
public final class KimiCodeAnthropicProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "kimi-code-anthropic",
                displayName: "Kimi Code (Anthropic)",
                description: "Kimi Code API via Anthropic-compatible endpoint.",
                defaultModel: "k3",
                models: [
                    LLMModelInfo(id: "k3", displayName: "Kimi K3", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "k3-256k", displayName: "Kimi K3 256K", contextWindowSize: 256_000, supportsVision: true),
                    LLMModelInfo(id: "kimi-for-coding", displayName: "Kimi K2.7 Code", contextWindowSize: 256_000, supportsVision: true),
                    LLMModelInfo(id: "kimi-for-coding-highspeed", displayName: "Kimi K2.7 Code High Speed", contextWindowSize: 256_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://www.moonshot.cn/")!,
                apiFormat: .anthropic,
                apiKeyStorageKey: "DevAssistant_ApiKey_KimiCode"
            ),
            apiService: apiService
        )
    }

    public override var anthropicConfiguration: AnthropicCompatibleProviderConfiguration? {
        AnthropicCompatibleProviderConfiguration(
            baseURL: "https://api.kimi.com/coding/v1/messages"
        )
    }

}
