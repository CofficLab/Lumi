import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public final class SublyxProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "sublyx",
            displayName: LumiPluginLocalization.string("Sublyx", bundle: .module),
            description: LumiPluginLocalization.string("GPT API Gateway by Sublyx", bundle: .module),
            defaultModel: "gpt-5.5",
            availableModels: [
                "gpt-5.5",
                "gpt-5.4",
                "gpt-5.4-mini",
                "gpt-4o",
                "gpt-4.1"
            ],
            contextWindowSizes: [
                "gpt-5.5": 1_000_000,
                "gpt-5.4": 1_000_000,
                "gpt-5.4-mini": 1_000_000,
                "gpt-4o": 128_000,
                "gpt-4.1": 1_000_000
            ],
            modelCapabilities: [
                "gpt-5.5": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4-mini": .init(supportsVision: true, supportsTools: true),
                "gpt-4o": .init(supportsVision: true, supportsTools: true),
                "gpt-4.1": .init(supportsVision: true, supportsTools: true)
            ],
            websiteURL: URL(string: "https://api.sublyx.org/")!
        )
    }

    public override class var apiKeyStorageKey: String {
        "DevAssistant_ApiKey_Sublyx"
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
                baseURL: "https://api.sublyx.org/v1/chat/completions",
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
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(
            providerID: Self.info.id,
            displayName: Self.info.displayName,
            isLocal: Self.info.isLocal
        )
    }
}
