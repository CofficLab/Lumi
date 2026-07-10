import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public final class LPgptProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "lpgpt",
            displayName: LumiPluginLocalization.string("LPgpt", bundle: .module),
            description: LumiPluginLocalization.string("Free LLM Gateway by lpgpt.us", bundle: .module),
            defaultModel: "gpt-5.4",
            availableModels: [
            "gpt-5.4",
            "gpt-5.5"
            ],
            contextWindowSizes: [
                "gpt-5.4": 1_000_000,
                "gpt-5.5": 1_000_000
            ],
            modelCapabilities: [
                "gpt-5.4": .init(supportsVision: true, supportsTools: true),
                "gpt-5.5": .init(supportsVision: true, supportsTools: true)
            ],
            websiteURL: URL(string: "https://lpgpt.us")!
        ,
            apiKeyStorageKey: "DevAssistant_ApiKey_LPgpt"
        )
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://lpgpt.us/v1/chat/completions",
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
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }
}
