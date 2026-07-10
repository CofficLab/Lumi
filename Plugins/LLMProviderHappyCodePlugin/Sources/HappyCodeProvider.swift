import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

public final class HappyCodeProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "happycode",
            displayName: LumiPluginLocalization.string("HappyCode", bundle: .module),
            description: LumiPluginLocalization.string("AI API Gateway by HappyCode", bundle: .module),
            defaultModel: "gpt-5.5",
            availableModels: [
            "gpt-5.5"
            ],
            contextWindowSizes: [
                "gpt-5.5": 1_000_000
            ],
            modelCapabilities: [
                "gpt-5.5": .init(supportsVision: true, supportsTools: true)
            ],
            websiteURL: URL(string: "https://happycode.vip")!
        ,
            apiKeyStorageKey: "DevAssistant_ApiKey_HappyCode"
        )
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
            baseURL: "https://happycode.vip/v1/chat/completions",
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
