import Foundation
import HttpKit
import LumiCoreKit
import LumiLLMProviderSupport

// MARK: - AvailabilityService

enum AvailabilityService {
    private static let cache = AvailabilityDiskCache(pluginName: "LLMProviderMiniMax")

    static func checkAvailability(
        provider: any LumiLLMProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        // 优先读磁盘缓存
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            return cached.result
        }

        let result = await provider.checkAvailability(model: model)
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
                    "This model is not included in your Token Plan",
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
            || lower.contains("model_not_found")
            || lower.contains("not supported in plan")
    }

    static func isUnsupportedModelError(_ error: Error) -> Bool {
        if case let HTTPClientError.httpError(_, message) = error {
            return isUnsupportedModelResponse(message)
        }

        return isUnsupportedModelFailure(LumiLLMFailureDetailResolver.resolve(from: error))
    }
}