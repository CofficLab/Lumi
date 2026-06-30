import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public final class FeifeimiaoProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "feifeimiao",
            displayName: LumiPluginLocalization.string("Feifeimiao", bundle: .module),
            description: LumiPluginLocalization.string("LLM API by feifeimiao", bundle: .module),
            defaultModel: "gpt-5.5",
            availableModels: [
            "gpt-5.5",
            "gpt-5.4",
            "gpt-5.4-mini",
            "gpt-5.3",
            "gpt-5.2"
            ],
            contextWindowSizes: [
                "gpt-5.5": 1_000_000,
                "gpt-5.4": 1_000_000,
                "gpt-5.4-mini": 400_000,
                "gpt-5.3": 400_000,
                "gpt-5.2": 400_000
            ],
            modelCapabilities: [
                "gpt-5.5": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4-mini": .init(supportsVision: true, supportsTools: true),
                "gpt-5.3": .init(supportsVision: true, supportsTools: true),
                "gpt-5.2": .init(supportsVision: true, supportsTools: true)
            ],
            websiteURL: URL(string: "https://feifeimiao.top")!
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_Feifeimiao"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://api.feifeimiao.top/v1/chat/completions",
            additionalHeaders: [:],
            includeUsageInStreamOptions: true,
            returnsEmptyChunkWhenNoDelta: false,
            acceptsFunctionScopedToolCallID: false
        )
        )
    }

    public override func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    public override func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(providerInfo: Self.info)
    }

}
