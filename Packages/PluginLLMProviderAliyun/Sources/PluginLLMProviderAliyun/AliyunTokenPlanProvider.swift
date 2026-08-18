import KitLLM
import Foundation
import ProviderLLMManager

/// 阿里云 TokenPlan 供应商（Anthropic 兼容协议，迁移自旧
/// `AliyunTokenPlanProvider`）。
@MainActor
public final class AliyunTokenPlanProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "aliyun-tokenplan",
                displayName: "阿里云 TokenPlan",
                description: "阿里云 DashScope Token Plan (Anthropic-compatible)",
                defaultModel: "qwen3.6-plus",
                models: [
                    LLMModelInfo(id: "qwen3.6-flash", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "qwen3.6-plus", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "qwen3.7-plus", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "qwen3.7-max", contextWindowSize: 1_000_000, supportsVision: false),
                    LLMModelInfo(id: "qwen-image-2.0", contextWindowSize: 32_768, supportsVision: true, supportsTools: false),
                    LLMModelInfo(id: "qwen-image-2.0-pro", contextWindowSize: 32_768, supportsVision: true, supportsTools: false),
                    LLMModelInfo(id: "wan2.7-image", contextWindowSize: 32_768, supportsVision: false, supportsTools: false),
                    LLMModelInfo(id: "wan2.7-image-pro", contextWindowSize: 32_768, supportsVision: false, supportsTools: false),
                    LLMModelInfo(id: "deepseek-v3.2", contextWindowSize: 131_072, supportsVision: false),
                    LLMModelInfo(id: "deepseek-v4-flash", contextWindowSize: 131_072, supportsVision: true),
                    LLMModelInfo(id: "deepseek-v4-pro", contextWindowSize: 131_072, supportsVision: true),
                    LLMModelInfo(id: "kimi-k2.5", contextWindowSize: 262_144, supportsVision: false),
                    LLMModelInfo(id: "kimi-k2.6", contextWindowSize: 262_144, supportsVision: true),
                    LLMModelInfo(id: "kimi-k2.7-code", contextWindowSize: 262_144, supportsVision: true),
                    LLMModelInfo(id: "glm-5", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "glm-5.1", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "glm-5.2", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "MiniMax-M2.5", contextWindowSize: 204_800, supportsVision: false),
                ],
                websiteURL: URL(string: "https://www.aliyun.com/product/bailian")!,
                apiFormat: .anthropic,
                apiKeyStorageKey: "DevAssistant_ApiKey_Aliyun"
            ),
            apiService: apiService
        )
    }

    public override var anthropicConfiguration: AnthropicCompatibleProviderConfiguration? {
        AnthropicCompatibleProviderConfiguration(
            baseURL: "https://token-plan.cn-beijing.maas.aliyuncs.com/apps/anthropic"
        )
    }

}
