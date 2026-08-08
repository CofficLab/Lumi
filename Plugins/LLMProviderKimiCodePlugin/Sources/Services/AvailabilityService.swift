import Foundation
import LumiKernel

enum AvailabilityService {
    private static let cache = AvailabilityDiskCache(pluginName: "LLMProviderKimiCodePlugin")

    static func checkAvailability(
        provider: KimiCodeOpenAIProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        await checkAvailability(model: model) { try await provider.ping(model: $0) }
    }

    static func checkAvailability(
        provider: KimiCodeAnthropicProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        await checkAvailability(model: model) { try await provider.ping(model: $0) }
    }

    private static func checkAvailability(
        model: String,
        ping: @Sendable (String) async throws -> Void
    ) async -> LumiModelAvailabilityResult {
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            return cached.result
        }

        let result: LumiModelAvailabilityResult
        do {
            try await ping(model)
            result = .available
        } catch {
            result = .unavailable(.message(error.localizedDescription))
        }
        cache.write(model: model, result: result, timestamp: Date())
        return result
    }
}