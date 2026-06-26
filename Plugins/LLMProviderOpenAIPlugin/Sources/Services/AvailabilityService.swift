import Foundation
import LumiCoreKit
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

        let result = await provider.performAvailabilityCheck(model: model)
        cache.write(model: model, result: result, timestamp: Date())
        return result
    }
}
