import Foundation
import LumiKernel

enum AvailabilityService {
    private static let cache = AvailabilityDiskCache(pluginName: "LLMProviderDeepSeekPlugin")

    static func checkAvailability(
        provider: DeepSeekProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            return cached.result
        }

        let result: LumiModelAvailabilityResult
        do {
            try await provider.ping(model: model)
            result = .available
        } catch {
            result = .unavailable(.message(error.localizedDescription))
        }
        cache.write(model: model, result: result, timestamp: Date())
        return result
    }
}
