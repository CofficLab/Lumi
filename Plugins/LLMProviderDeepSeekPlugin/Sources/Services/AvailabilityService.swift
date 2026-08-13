import Foundation
import KernelLumi

enum AvailabilityService {
    private static let cache = AvailabilityDiskCache(pluginName: "LLMProviderDeepSeekPlugin")

    /// 检查 `DeepSeekOpenAIProvider`（OpenAI 协议）的可用性，命中缓存则直接返回。
    static func checkAvailability(
        provider: DeepSeekOpenAIProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        await checkAvailability(model: model) { try await provider.ping(model: $0) }
    }

    /// 检查 `DeepSeekAnthropicProvider`（Anthropic 协议）的可用性，命中缓存则直接返回。
    static func checkAvailability(
        provider: DeepSeekAnthropicProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        await checkAvailability(model: model) { try await provider.ping(model: $0) }
    }

    /// 共享实现：被两个具体 provider 的重载委托。
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
