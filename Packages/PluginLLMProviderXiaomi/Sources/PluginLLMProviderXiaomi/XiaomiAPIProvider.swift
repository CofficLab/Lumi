import ProviderLLMVendors
import Foundation
import ProviderLLMManager
import ProviderNetwork

/// Xiaomi API 供应商（独立端点，迁移自旧 `XiaomiAPIProvider`）。
@MainActor
public final class XiaomiAPIProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "xiaomi-api",
                displayName: "Xiaomi API",
                description: "Xiaomi API AI Models",
                defaultModel: "mimo-v2.5-pro",
                models: [
                    LLMModelInfo(id: "mimo-v2.5-pro", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "mimo-v2.5", contextWindowSize: 1_000_000, supportsVision: false),
                    LLMModelInfo(id: "mimo-v2.5-tts", contextWindowSize: 131_072, supportsVision: false, supportsTools: false),
                    LLMModelInfo(id: "mimo-v2.5-tts-voiceclone", contextWindowSize: 131_072, supportsVision: false, supportsTools: false),
                    LLMModelInfo(id: "mimo-v2.5-tts-voicedesign", contextWindowSize: 131_072, supportsVision: false, supportsTools: false),
                ],
                websiteURL: URL(string: "https://www.mi.com")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_XiaomiAPI"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.xiaomimimo.com/v1/chat/completions"
        )
    }

    /// 便捷初始化：注入 `NetworkProviding` 以支持 HTTP 交换记录。
    public convenience init(networkProvider: (any NetworkProviding)?) {
        let apiService = VendorAPIService(networkProvider: networkProvider)
        self.init(apiService: apiService)
    }
}
