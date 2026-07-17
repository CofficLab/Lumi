import Foundation
import HttpKit
import LLMKit
import LumiCoreKit
import LumiLLMProviderSupport

// MARK: - AvailabilityService

enum AvailabilityService {
    private static let cache = AvailabilityDiskCache(pluginName: "LLMProviderAliyun")

    static func checkAvailability(
        provider: AliyunTokenPlanProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        await checkAvailability(
            model: model,
            adapter: provider.internalAdapter,
            apiService: provider.internalApiService,
            buildRequest: { url, apiKey in
                provider.internalAdapter.buildRequest(url: url, apiKey: apiKey)
            },
            resolveAPIKey: { try provider.lumiResolveAPIKey() }
        )
    }

    static func checkAvailability(
        provider: AliyunProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        await checkAvailability(
            model: model,
            adapter: provider.internalAdapter,
            apiService: provider.internalApiService,
            buildRequest: { url, apiKey in
                provider.internalAdapter.buildRequest(url: url, apiKey: apiKey)
            },
            resolveAPIKey: { try provider.lumiResolveAPIKey() }
        )
    }

    private static func checkAvailability(
        model: String,
        adapter: AnthropicCompatibleProviderAdapter,
        apiService: LLMAPIService,
        buildRequest: @escaping (URL, String) -> URLRequest,
        resolveAPIKey: @escaping () throws -> String
    ) async -> LumiModelAvailabilityResult {
        // 优先读磁盘缓存
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            return cached.result
        }

        let result = await LumiAnthropicCompatibleAvailability.chatPing(
            model: model,
            adapter: adapter,
            apiService: apiService,
            buildRequest: buildRequest,
            resolveAPIKey: resolveAPIKey
        )
        let mapped = mapUnsupportedModelResult(result)

        cache.write(model: model, result: mapped, timestamp: Date())

        return mapped
    }

    static func mapUnsupportedModelResult(
        _ result: LumiModelAvailabilityResult
    ) -> LumiModelAvailabilityResult {
        guard case .unavailable(let failure) = result else { return result }
        guard isUnsupportedModelFailure(failure) else { return result }

        return .unavailable(
            failure.remapped(
                summary: LumiPluginLocalization.string(
                    "This model is not included in your Coding Plan",
                    bundle: .module
                ),
                reason: .unsupportedModel
            )
        )
    }

    static func isUnsupportedModelFailure(_ failure: LumiLLMFailureDetail) -> Bool {
        if failure.reason == .unsupportedModel {
            return true
        }

        let combined = [failure.summary, failure.transportDetails]
            .compactMap { $0 }
            .joined(separator: "\n")
        return isUnsupportedModelResponse(combined)
    }

    static func isUnsupportedModelResponse(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("invalid_parameter")
    }

    static func isUnsupportedModelError(_ error: Error) -> Bool {
        if case let HTTPClientError.httpError(_, message) = error {
            return isUnsupportedModelResponse(message)
        }

        return isUnsupportedModelFailure(LumiLLMFailureDetailResolver.resolve(from: error))
    }
}