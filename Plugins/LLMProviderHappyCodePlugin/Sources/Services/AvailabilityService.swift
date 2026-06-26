import LumiCoreKit
import LumiLLMProviderSupport

enum AvailabilityService {
    private static let cache = AvailabilityDiskCache(pluginName: "LLMProviderHappyCodePlugin")

    static func checkAvailability(
        provider: HappyCodeProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            return cached.result
        }

        let result = await provider.checkAvailabilityUsingChatPing(model: model)
        cache.write(model: model, result: result, timestamp: Date())
        return result
    }
}
