import KitLLM
import Foundation
import ProviderLLMManager

/// Xiaomi TokenPlan 供应商（迁移自旧 LLMProviderXiaomiPlugin）。
@MainActor
public final class XiaomiProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "xiaomi",
                displayName: "Xiaomi TokenPlan",
                description: "Xiaomi TokenPlan AI Models",
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
                apiKeyStorageKey: "DevAssistant_ApiKey_Xiaomi"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://token-plan-cn.xiaomimimo.com/v1/chat/completions"
        )
    }

}
