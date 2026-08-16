import ProviderLLMVendors
import Foundation
import ProviderLLMManager

/// StepFun StepPlan 供应商（迁移自旧 LLMProviderStepFunPlugin）。
@MainActor
public final class StepFunProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "stepfun",
                displayName: "StepFun StepPlan",
                description: "StepFun StepPlan AI",
                defaultModel: "step-3.5-flash",
                models: [
                    LLMModelInfo(id: "step-3.7-flash", contextWindowSize: 262_144, supportsVision: true),
                    LLMModelInfo(id: "step-router-v1", contextWindowSize: 262_144, supportsVision: false, supportsTools: false),
                    LLMModelInfo(id: "stepaudio-2.5-chat", contextWindowSize: 1_000_000, supportsVision: false),
                    LLMModelInfo(id: "stepaudio-2.5-tts", contextWindowSize: 1_000_000, supportsVision: false, supportsTools: false),
                    LLMModelInfo(id: "stepaudio-2.5-asr", contextWindowSize: 1_000_000, supportsVision: false, supportsTools: false),
                    LLMModelInfo(id: "stepaudio-2.5-realtime", contextWindowSize: 1_000_000, supportsVision: false),
                    LLMModelInfo(id: "step-image-edit-2", contextWindowSize: 1_000_000, supportsVision: true, supportsTools: false),
                    LLMModelInfo(id: "step-3.5-flash-2603", contextWindowSize: 262_144, supportsVision: true),
                    LLMModelInfo(id: "step-3.5-flash", contextWindowSize: 262_144, supportsVision: true),
                ],
                websiteURL: URL(string: "https://www.stepfun.com/")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_StepFun"
            ),
            apiService: apiService
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.stepfun.com/step_plan/v1/chat/completions"
        )
    }
}
