import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public final class FlyMuxProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    private static let apiKeyStorageKey = "DevAssistant_ApiKey_FlyMux"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "flymux",
            displayName: LumiPluginLocalization.string("FlyMux", bundle: .module),
            description: LumiPluginLocalization.string("AI API Gateway by flymux.com", bundle: .module),
            defaultModel: "gpt-5.1-codex",
            availableModels: [
            "gpt-5.4",
            "gpt-5.4-mini",
            "gpt-5.4-openai-compact",
            "gpt-5.3",
            "gpt-5.3-codex",
            "gpt-5.2",
            "gpt-5.2-codex",
            "gpt-5.1",
            "gpt-5.1-codex",
            "gpt-5.1-codex-max",
            "gpt-5.1-codex-mini"
            ],
            contextWindowSizes: [
                "gpt-5.4": 1_000_000,
                "gpt-5.4-mini": 400_000,
                "gpt-5.4-openai-compact": 400_000,
                "gpt-5.3": 400_000,
                "gpt-5.3-codex": 400_000,
                "gpt-5.2": 400_000,
                "gpt-5.2-codex": 400_000,
                "gpt-5.1": 400_000,
                "gpt-5.1-codex": 400_000,
                "gpt-5.1-codex-max": 400_000,
                "gpt-5.1-codex-mini": 400_000
            ],
            modelCapabilities: [
                "gpt-5.4": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4-mini": .init(supportsVision: true, supportsTools: true),
                "gpt-5.4-openai-compact": .init(supportsVision: true, supportsTools: true),
                "gpt-5.3": .init(supportsVision: true, supportsTools: true),
                "gpt-5.3-codex": .init(supportsVision: true, supportsTools: true),
                "gpt-5.2": .init(supportsVision: true, supportsTools: true),
                "gpt-5.2-codex": .init(supportsVision: true, supportsTools: true),
                "gpt-5.1": .init(supportsVision: true, supportsTools: true),
                "gpt-5.1-codex": .init(supportsVision: true, supportsTools: true),
                "gpt-5.1-codex-max": .init(supportsVision: true, supportsTools: true),
                "gpt-5.1-codex-mini": .init(supportsVision: true, supportsTools: true)
            ],
            websiteURL: URL(string: "https://flymux.com")!
        )
    }

    override public func lumiResolveAPIKey() throws -> String {
        let key = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: Self.apiKeyStorageKey) ?? ""
        if key.isEmpty {
            throw LumiLLMProviderSupportError.missingAPIKey(Self.info.displayName)
        }
        return key
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://api.flymux.com/v1/chat/completions",
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
