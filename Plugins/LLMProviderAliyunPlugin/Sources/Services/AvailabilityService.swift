import Foundation
import HttpKit
import LLMKit
import LumiKernel

// MARK: - AliyunAvailabilityService

enum AliyunAvailabilityService {
    private static let cache = AvailabilityDiskCache(pluginName: "LLMProviderAliyun")

    static func checkAvailability(
        provider: AliyunTokenPlanProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        await checkAvailability(
            model: model,
            ping: { try await provider.ping(model: $0) }
        )
    }

    static func checkAvailability(
        provider: AliyunProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        await checkAvailability(
            model: model,
            ping: { try await provider.ping(model: $0) }
        )
    }

    private static func checkAvailability(
        model: String,
        ping: @escaping (String) async throws -> Void
    ) async -> LumiModelAvailabilityResult {
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            return cached.result
        }

        let result = await pingProvider(model: model, ping: ping)
        let mapped = mapUnsupportedModelResult(result)

        cache.write(model: model, result: mapped, timestamp: Date())

        return mapped
    }

    private static func pingProvider(
        model: String,
        ping: @escaping (String) async throws -> Void
    ) async -> LumiModelAvailabilityResult {
        do {
            try await ping(model)
            return .available
        } catch {
            if isUnsupportedModelError(error) {
                return .unavailable(LumiLLMFailureDetail(
                    summary: LumiPluginLocalization.string(
                        "This model is not included in your Coding Plan",
                        bundle: .module
                    ),
                    reason: .unsupportedModel
                ))
            }
            return .unavailable(LumiLLMFailureDetailResolver.resolve(from: error))
        }
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
