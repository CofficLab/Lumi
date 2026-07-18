import Foundation
import HttpKit
import LLMKit
import LumiCoreKit
import LLMKit
import LumiCoreKit
import SuperLogKit

enum AvailabilityService: SuperLog {
    private static let cache = AvailabilityDiskCache(pluginName: "LLMProviderStepFunPlugin")
    static let verbose: Bool = false

    static func checkAvailability(
        provider: StepFunProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            if Self.verbose {
                StepFunPlugin.logger.info("\(Self.t)命中缓存 model=\(model)")
            }
            return cached.result
        }

        if Self.verbose {
            StepFunPlugin.logger.info("\(Self.t)开始检查可用性 model=\(model)")
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
        if Self.verbose {
            StepFunPlugin.logger.info("\(Self.t)可用性检查完成 model=\(model)")
        }
        return result
    }
}