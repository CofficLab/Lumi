import ProviderLLMVendors
import Foundation
import ProviderLLMManager

/// 智谱 API 供应商（迁移自旧 LLMProviderZhipuPlugin 的 `ZhipuAPIProvider`）。
@MainActor
public final class ZhipuProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "zhipu-api",
                displayName: "智谱 API",
                description: "Zhipu AI GLM (OpenAI-compatible)",
                defaultModel: "glm-4.7",
                models: [
                    LLMModelInfo(id: "glm-5.2", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "glm-5.1", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "glm-5-turbo", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "glm-5", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "glm-4.7", contextWindowSize: 128_000, supportsVision: false),
                    LLMModelInfo(id: "glm-4.6", contextWindowSize: 200_000, supportsVision: true),
                    LLMModelInfo(id: "glm-4.5", contextWindowSize: 128_000, supportsVision: true),
                    LLMModelInfo(id: "glm-4.5-air", contextWindowSize: 128_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://www.bigmodel.cn/")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_ZhipuAPI"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        )
    }
}
