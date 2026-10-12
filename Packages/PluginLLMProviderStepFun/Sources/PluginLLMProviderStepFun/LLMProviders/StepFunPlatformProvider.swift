import Foundation
import KitLLM
import ProviderLLMManager

/// StepFun 开放平台供应商（OpenAI Chat Completions 兼容协议）。
///
/// 与 Step Plan 共享 API Key，但使用标准 `/v1/chat/completions` 端点和
/// 开放平台模型目录。
@MainActor
public final class StepFunPlatformProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "stepfun-platform",
                displayName: "StepFun 开放平台",
                description: "阶跃星辰开放平台",
                defaultModel: "step-5-preview",
                models: [
                    LLMModelInfo(
                        id: "step-5-preview",
                        displayName: "Step 5 Preview",
                        contextWindowSize: 1_000_000,
                        supportsVision: true
                    ),
                    LLMModelInfo(
                        id: "step-3.7-flash",
                        displayName: "Step 3.7 Flash",
                        contextWindowSize: 262_144,
                        supportsVision: true
                    ),
                    LLMModelInfo(
                        id: "step-3.5-flash-2603",
                        displayName: "Step 3.5 Flash 2603",
                        contextWindowSize: 262_144
                    ),
                    LLMModelInfo(
                        id: "step-3.5-flash",
                        displayName: "Step 3.5 Flash",
                        contextWindowSize: 262_144
                    ),
                    LLMModelInfo(
                        id: "stepaudio-3-chat-preview",
                        displayName: "StepAudio 3 Chat Preview",
                        contextWindowSize: 1_000_000
                    ),
                    LLMModelInfo(
                        id: "stepaudio-2.5-chat",
                        displayName: "StepAudio 2.5 Chat",
                        contextWindowSize: 1_000_000
                    ),
                ],
                websiteURL: URL(string: "https://platform.stepfun.com/")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_StepFun"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.stepfun.com/v1/chat/completions"
        )
    }
}
