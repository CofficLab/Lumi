import LumiCoreKit
import LumiLLMProviderSupport

final class FreeModelOpenAIBackend: OpenAICompatibleLumiProvider, @unchecked Sendable {
    override class var info: LumiLLMProviderInfo { FreeModelProvider.providerInfo }

    init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
                baseURL: FreeModelProvider.Endpoints.openAIPrimary,
                fallbackBaseURLs: [FreeModelProvider.Endpoints.openAIFallback],
                additionalHeaders: [:],
                includeUsageInStreamOptions: true,
                returnsEmptyChunkWhenNoDelta: false,
                acceptsFunctionScopedToolCallID: false
            )
        )
    }

    public override func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await checkAvailabilityUsingChatPing(model: model)
    }

    override func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }
}
