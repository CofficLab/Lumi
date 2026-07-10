import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public final class DeepSeekProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "deepseek",
            displayName: LumiPluginLocalization.string("DeepSeek", bundle: .module),
            description: LumiPluginLocalization.string("DeepSeek AI", bundle: .module),
            defaultModel: "deepseek-v4-flash",
            availableModels: [
                "deepseek-v4-flash",
                "deepseek-v4-pro"
            ],
            contextWindowSizes: [
                "deepseek-v4-flash": 1_000_000,
                "deepseek-v4-pro": 1_000_000
            ],
            modelCapabilities: [
                "deepseek-v4-flash": .init(supportsVision: false, supportsTools: true),
                "deepseek-v4-pro": .init(supportsVision: false, supportsTools: true)
            ],
            websiteURL: URL(string: "https://www.deepseek.com/")!
        ,
            apiKeyStorageKey: "DevAssistant_ApiKey_DeepSeek"
        )
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
                baseURL: "https://api.deepseek.com/v1/chat/completions",
                additionalHeaders: [:],
                includeUsageInStreamOptions: false,
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
