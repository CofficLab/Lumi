import Foundation
import LumiKernel
import LLMKit
import LumiLLMProviderSupport
enum AvailabilityService {
    private static let openAICache = AvailabilityDiskCache(pluginName: "LLMProviderKimiCodePlugin-OpenAI")
    private static let anthropicCache = AvailabilityDiskCache(pluginName: "LLMProviderKimiCodePlugin-Anthropic")

    static func checkAvailabilityForOpenAI(
        provider: KimiCodeOpenAIProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        if let cached = openAICache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < openAICache.cacheInterval {
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
        openAICache.write(model: model, result: result, timestamp: Date())
        return result
    }

    static func checkAvailabilityForAnthropic(
        provider: KimiCodeAnthropicProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        if let cached = anthropicCache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < anthropicCache.cacheInterval {
            return cached.result
        }

        let result = await LumiAnthropicCompatibleAvailability.chatPing(
            model: model,
            adapter: provider.internalAdapter,
            apiService: provider.internalApiService,
            buildRequest: { url, apiKey in
                provider.internalAdapter.buildRequest(url: url, apiKey: apiKey)
            },
            resolveAPIKey: { try provider.lumiResolveAPIKey() }
        )
        anthropicCache.write(model: model, result: result, timestamp: Date())
        return result
    }
}