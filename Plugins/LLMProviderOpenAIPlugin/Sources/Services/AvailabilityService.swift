import Foundation
import LLMKit
import LumiCoreLLMProvider
import LumiCoreMessage
import LumiKernel
import LumiLLMProviderSupport

enum AvailabilityService {
    private static let cache = AvailabilityDiskCache(pluginName: "LLMProviderOpenAIPlugin")

    static func checkAvailability(
        provider: OpenAIProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            return cached.result
        }

        let result = await LumiOpenAICompatibleAvailability.chatPing(
            model: model,
            adapter: provider.internalAdapter,
            apiService: provider.internalApiService,
            buildRequest: { url, apiKey in
                provider.internalAdapter.buildRequest(url: url, apiKey: apiKey)
            },
            resolveAPIKey: { try provider.lumiResolveAPIKey() }
        )
        cache.write(model: model, result: result, timestamp: Date())
        return result
    }
}