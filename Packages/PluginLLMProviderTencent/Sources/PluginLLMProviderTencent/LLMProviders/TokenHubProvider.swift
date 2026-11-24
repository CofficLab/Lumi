import Foundation
import KitLLM
import ProviderLLMManager

/// 腾讯云 TokenHub 供应商（OpenAI Chat Completions 兼容协议）。
@MainActor
public final class TokenHubProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "tencent",
                displayName: "腾讯云 TokenHub",
                description: "Tencent Cloud TokenHub",
                defaultModel: "hy4-preview",
                models: [
                    // 文本生成
                    LLMModelInfo(id: "hy4-preview", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "hy3", displayName: "Hy3", contextWindowSize: 256_000),
                    LLMModelInfo(id: "kimi-k3", displayName: "Kimi K3", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "kimi-k2.7-code", displayName: "Kimi K2.7 Code", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "kimi-k2.7-code-highspeed", displayName: "Kimi K2.7 Code Highspeed", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "kimi-k2.5", displayName: "Kimi K2.5", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "deepseek-v4-pro-202606", displayName: "DeepSeek-V4-Pro 202606 正式版", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "deepseek-v4-pro-0813", displayName: "DeepSeek-V4-Pro 0813 正式版", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "deepseek-v3.2", displayName: "DeepSeek-V3.2", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "glm-5.3", displayName: "GLM-5.3", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "glm-5.2", displayName: "GLM-5.2", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "glm-5.1", displayName: "GLM-5.1", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "glm-5", displayName: "GLM-5", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "glm-5-turbo", displayName: "GLM-5-Turbo", contextWindowSize: 128_000),
                    LLMModelInfo(id: "minimax-m3", displayName: "MiniMax-M3", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "minimax-m2.7", displayName: "MiniMax-M2.7", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "qwen3.5-plus", displayName: "Qwen3.5-Plus", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "deepseek-v4-flash", displayName: "DeepSeek-V4-Flash", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "deepseek-v4-flash-0731", displayName: "DeepSeek-V4-Flash 0731 正式版", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "hy-mt2-pro", displayName: "HY-MT2-Pro", contextWindowSize: 1_000_000),
                    // 只列出支持 Chat Completions 的模型（#414）：图像、视频、
                    // 3D、语音等模型走的是各自专用协议，放进聊天供应商清单
                    // 会继承流式/工具默认能力，选中后请求发往 Chat Completions
                    // 必然报协议或能力错误。
                    // 多模态理解
                    LLMModelInfo(id: "deepseek/deepseek-v4-flash-vision-exp", displayName: "DeepSeek-V4-Flash-Vision-Exp", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "hy-vision-2.0-instruct", displayName: "HY-Vision-2.0-Instruct", contextWindowSize: 44_000, supportsVision: true),
                    LLMModelInfo(id: "glm-5.3-flash", displayName: "GLM-5.3-Flash", contextWindowSize: 1_000_000, supportsVision: true),
                ],
                websiteURL: URL(string: "https://cloud.tencent.com/product/tokenhub"),
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_Tencent"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://tokenhub.tencentmaas.com/v1/chat/completions"
        )
    }
}
