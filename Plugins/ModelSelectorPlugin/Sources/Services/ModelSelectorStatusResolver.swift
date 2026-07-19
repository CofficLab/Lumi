import LumiKernel
import LumiKernel

enum ModelSelectorStatusResolver {
    @MainActor
    static func resolve(
        provider: LumiLLMProviderInfo,
        chatService: ChatService
    ) -> LumiLLMProviderStatus? {
        resolve(
            provider: provider,
            providerInstance: chatService.provider(forID: provider.id)
        )
    }

    static func resolve(
        provider: LumiLLMProviderInfo,
        providerInstance: (any LumiLLMProvider)?
    ) -> LumiLLMProviderStatus? {
        providerInstance?.providerStatus()
    }
}
