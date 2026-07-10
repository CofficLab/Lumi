import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public final class HyperAPIProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "hyperapi",
            displayName: LumiPluginLocalization.string("HyperAPI", bundle: .module),
            description: LumiPluginLocalization.string("LLM Router by hyperapi.cc", bundle: .module),
            defaultModel: "gpt-5",
            availableModels: [
            "gpt-5.1-codex-max",
            "gpt-5.2-codex",
            "gpt-5.4-mini",
            "gpt-5",
            "gpt-5.1-codex-mini",
            "gpt-5.2",
            "gpt-5.3-codex",
            "gpt-5.4",
            "gpt-5-codex",
            "gpt-5.1",
            "gpt-5.1-codex"
            ],
            contextWindowSizes: [
                "gpt-5": 400_000,
                "gpt-5-codex": 400_000,
                "gpt-5.1": 400_000,
                "gpt-5.1-codex": 400_000,
                "gpt-5.1-codex-max": 400_000,
                "gpt-5.1-codex-mini": 400_000,
                "gpt-5.2": 400_000,
                "gpt-5.2-codex": 400_000,
                "gpt-5.3-codex": 400_000,
                "gpt-5.4": 1_000_000,
                "gpt-5.4-mini": 400_000
            ],
            modelCapabilities: [
                "gpt-5": .init(supportsVision: true, supportsTools: true),
                "gpt-5-codex": .init(supportsVision: true, supportsTools: true),
                "gpt-5.1": .init(supportsVision: true, supportsTools: true),
                "gpt-5.1-codex": .init(supportsVision: true, supportsTools: true),
                "gpt-5.1-codex-max": .init(supportsVision: true, supportsTools: true),
                "gpt-5.1-codex-mini": .init(supportsVision: true, supportsTools: true),
                "gpt-5.2": .init(supportsVision: true, supportsTools: true),
                "gpt-5.2-codex": .init(supportsVision: true, supportsTools: true),
                "gpt-5.3-codex": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4-mini": .init(supportsVision: true, supportsTools: true)
            ],
            websiteURL: URL(string: "https://hyperapi.cc")!
        ,
            apiKeyStorageKey: "DevAssistant_ApiKey_HyperAPI"
        )
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://hyperapi.cc/v1/chat/completions",
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
