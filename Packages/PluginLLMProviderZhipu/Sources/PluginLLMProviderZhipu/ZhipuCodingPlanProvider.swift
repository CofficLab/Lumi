import ProviderLLMVendors
import Foundation
import ProviderLLMManager

/// 智谱 Coding Plan 供应商（Anthropic 协议，迁移自旧 `ZhipuProvider`）。
@MainActor
public final class ZhipuCodingPlanProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "zhipu",
                displayName: "智谱 Coding Plan",
                description: "Zhipu AI GLM (Anthropic-compatible)",
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
                apiFormat: .anthropic,
                apiKeyStorageKey: "DevAssistant_ApiKey_Zhipu"
            ),
            apiService: apiService
        )
    }

    public override var anthropicConfiguration: AnthropicCompatibleProviderConfiguration? {
        AnthropicCompatibleProviderConfiguration(
            baseURL: "https://open.bigmodel.cn/api/anthropic/v1/messages"
        )
    }
}
