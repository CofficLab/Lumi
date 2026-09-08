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
                    LLMModelInfo(id: "deepseek-v4-flash-0731", displayName: "DeepSeek-V4-Flash 0731 正式版", contextWindowSize: 1_000_000),
                    // 图像生成
                    LLMModelInfo(id: "hy-image-v3", displayName: "Hy-Image-3.0"),
                    LLMModelInfo(id: "vidu-image-q2", displayName: "Vidu-Image-q2"),
                    // 视频生成
                    LLMModelInfo(id: "minimax-video-h3", displayName: "MiniMax-Video-H3"),
                    LLMModelInfo(id: "pixverse-video-c1", displayName: "Pixverse-Video-c1"),
                    LLMModelInfo(id: "kling-video-v3", displayName: "Kling-Video-V3"),
                    // 3D 生成
                    LLMModelInfo(id: "hy-3d-3.1", displayName: "HY-3D-3.1"),
                    LLMModelInfo(id: "hy-3d-3.0", displayName: "HY-3D-3.0"),
                    LLMModelInfo(id: "hy-3d-express", displayName: "HY-3D-Express"),
                    // 多模态理解
                    LLMModelInfo(id: "deepseek/deepseek-v4-flash-vision-exp", displayName: "DeepSeek-V4-Flash-Vision-Exp", contextWindowSize: 1_000_000, supportsVision: true),
                    LLMModelInfo(id: "hy-vision-2.0-instruct", displayName: "HY-Vision-2.0-Instruct", contextWindowSize: 44_000, supportsVision: true),
                    LLMModelInfo(id: "glm-5.3-flash", displayName: "GLM-5.3-Flash", contextWindowSize: 1_000_000, supportsVision: true),
                    // 语音模型
                    LLMModelInfo(id: "hy-asr-3.0-preview", displayName: "Hy-ASR-3.0-preview"),
                    LLMModelInfo(id: "minimax-speech-2.8-hd", displayName: "MiniMax-Speech-2.8-HD"),
                    LLMModelInfo(id: "minimax-music-v2.6", displayName: "MiniMax-Music-v2.6"),
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
