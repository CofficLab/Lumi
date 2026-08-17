import ProviderLLMVendors
import Foundation
import ProviderLLMManager
import ProviderNetwork

/// 阿里云 CodingPlan 供应商（Anthropic 兼容协议，迁移自旧 LLMProviderAliyunPlugin）。
@MainActor
public final class AliyunProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "aliyun",
                displayName: "阿里云 CodingPlan",
                description: "阿里云 DashScope Coding Plan",
                defaultModel: "qwen3.6-plus",
                models: [
                    LLMModelInfo(id: "qwen3.7-plus", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "qwen3.6-plus", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "qwen3.5-plus", contextWindowSize: 131_072, supportsVision: true),
                    LLMModelInfo(id: "qwen3-max-2026-01-23", contextWindowSize: 1_000_000, supportsVision: false),
                    LLMModelInfo(id: "qwen3-coder-next", contextWindowSize: 1_000_000, supportsVision: false, supportsTools: false),
                    LLMModelInfo(id: "qwen3-coder-plus", contextWindowSize: 1_000_000, supportsVision: false, supportsTools: false),
                    LLMModelInfo(id: "kimi-k2.5", contextWindowSize: 262_144, supportsVision: true),
                    LLMModelInfo(id: "glm-5", contextWindowSize: 1_000_000, supportsVision: false),
                    LLMModelInfo(id: "glm-4.7", contextWindowSize: 128_000, supportsVision: false),
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
            baseURL: "https://coding.dashscope.aliyuncs.com/apps/anthropic"
        )
    }

    /// 便捷初始化：注入 `NetworkProviding` 以支持 HTTP 交换记录。
    public convenience init(networkProvider: (any NetworkProviding)?) {
        let apiService = VendorAPIService(networkProvider: networkProvider)
        self.init(apiService: apiService)
    }
}
