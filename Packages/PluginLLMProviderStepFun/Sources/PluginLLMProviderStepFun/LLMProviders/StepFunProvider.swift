import KitLLM
import Foundation
import ProviderLLMManager

/// StepFun Step Plan 供应商。
///
/// `step-router-v1` 只能通过 Step Plan 端点调用。开放平台模型由
/// `StepFunPlatformProvider` 独立承载，避免把模型发送到错误的通道。
@MainActor
public final class StepFunProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "stepfun",
                displayName: "StepFun Step Plan",
                description: "Step Plan 智能路由服务",
                defaultModel: "step-router-v1",
                models: [
                    LLMModelInfo(
                        id: "step-router-v1",
                        displayName: "Step Router V1",
                        contextWindowSize: 262_144,
                        supportsVision: false,
                        supportsTools: true
                    ),
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
