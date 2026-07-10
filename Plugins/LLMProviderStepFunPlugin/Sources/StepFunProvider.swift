import Foundation
import LumiCoreKit
import LumiLLMProviderSupport
import os
import SuperLogKit

public final class StepFunProvider: OpenAICompatibleLumiProvider, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "🌟"
    nonisolated static let verbose: Int = 0
    public static let shortName = "StepFun StepPlan"

    override public class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "stepfun",
            displayName: LumiPluginLocalization.string("StepFun StepPlan", bundle: .module),
            description: LumiPluginLocalization.string("StepFun StepPlan AI", bundle: .module),
            defaultModel: "step-3.5-flash",
            availableModels: [
                "step-3.7-flash",
                "step-router-v1",
                "stepaudio-2.5-chat",
                "stepaudio-2.5-tts",
                "stepaudio-2.5-asr",
                "stepaudio-2.5-realtime",
                "step-image-edit-2",
                "step-3.5-flash-2603",
                "step-3.5-flash",
            ],
            contextWindowSizes: [
                "step-3.7-flash": 262144,
                "step-router-v1": 262144,
                "stepaudio-2.5-chat": 1000000,
                "stepaudio-2.5-tts": 1000000,
                "stepaudio-2.5-asr": 1000000,
                "stepaudio-2.5-realtime": 1000000,
                "step-image-edit-2": 1000000,
                "step-3.5-flash-2603": 262144,
                "step-3.5-flash": 262144,
            ],
            modelCapabilities: [
                "step-3.7-flash": .init(supportsVision: true, supportsTools: true),
                "step-router-v1": .init(supportsVision: false, supportsTools: false),
                "stepaudio-2.5-chat": .init(supportsVision: false, supportsTools: true),
                "stepaudio-2.5-tts": .init(supportsVision: false, supportsTools: false),
                "stepaudio-2.5-asr": .init(supportsVision: false, supportsTools: false),
                "stepaudio-2.5-realtime": .init(supportsVision: false, supportsTools: true),
                "step-image-edit-2": .init(supportsVision: true, supportsTools: false),
                "step-3.5-flash-2603": .init(supportsVision: true, supportsTools: true),
                "step-3.5-flash": .init(supportsVision: true, supportsTools: true),
            ],
            websiteURL: URL(string: "https://www.stepfun.com/")!
        ,
            apiKeyStorageKey: "DevAssistant_ApiKey_StepFun"
        )
    }

    public static let apiKeyHelpURL: String? = "https://www.stepfun.com/#/api"

    // MARK: - Provider Status

    override public func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
                baseURL: "https://api.stepfun.com/step_plan/v1/chat/completions",
                additionalHeaders: ["Accept": "text/event-stream"],
                includeUsageInStreamOptions: false,
                returnsEmptyChunkWhenNoDelta: false,
                acceptsFunctionScopedToolCallID: false
            )
        )
    }
}
