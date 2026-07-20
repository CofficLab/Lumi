import Foundation
import HttpKit
import LLMKit
import LumiCoreMessage
import LumiKernel
import LumiLLMProviderSupport

enum AvailabilityService {
    private static let cache = AvailabilityDiskCache(pluginName: "LLMProviderXiaomiPlugin")

    enum ProviderKind {
        case tokenPlan
        case api

        var unsupportedModelMessage: String {
            switch self {
            case .tokenPlan:
                return LumiPluginLocalization.string(
                    "This model is not included in your Token Plan",
                    bundle: .module
                )
            case .api:
                return LumiPluginLocalization.string(
                    "This model is not available on Xiaomi API",
                    bundle: .module
                )
            }
        }
    }

    static func checkAvailability(
        provider: XiaomiProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            return cached.result
        }

        let result = await mapFriendlyFailureResult(
            await LumiOpenAICompatibleAvailability.chatPing(
                model: model,
                adapter: provider.internalAdapter,
                apiService: provider.internalApiService,
                buildRequest: { url, apiKey in
                    provider.internalAdapter.buildRequest(url: url, apiKey: apiKey)
                },
                resolveAPIKey: { try provider.lumiResolveAPIKey() }
            ),
            kind: .tokenPlan
        )

        cache.write(model: model, result: result, timestamp: Date())
        return result
    }

    static func checkAvailability(
        provider: XiaomiAPIProvider,
        model: String
    ) async -> LumiModelAvailabilityResult {
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            return cached.result
        }

        let result = await mapFriendlyFailureResult(
            await LumiOpenAICompatibleAvailability.chatPing(
                model: model,
                adapter: provider.internalAdapter,
                apiService: provider.internalApiService,
                buildRequest: { url, apiKey in
                    provider.internalAdapter.buildRequest(url: url, apiKey: apiKey)
                },
                resolveAPIKey: { try provider.lumiResolveAPIKey() }
            ),
            kind: .api
        )

        cache.write(model: model, result: result, timestamp: Date())
        return result
    }

    static func mapFriendlyFailureResult(
        _ result: LumiModelAvailabilityResult,
        kind: ProviderKind
    ) -> LumiModelAvailabilityResult {
        guard case .unavailable(let failure) = result else { return result }

        if isUnsupportedModelFailure(failure) {
            return .unavailable(
                failure.remapped(
                    summary: kind.unsupportedModelMessage,
                    reason: .unsupportedModel
                )
            )
        }

        if isInvalidAPIKeyFailure(failure) {
            return .unavailable(
                failure.remapped(
                    summary: LumiPluginLocalization.string(
                        "Xiaomi API Key is invalid or expired",
                        bundle: .module
                    )
                )
            )
        }

        if isQuotaExhaustedFailure(failure) {
            return .unavailable(
                failure.remapped(
                    summary: LumiPluginLocalization.string(
                        "Xiaomi quota exhausted or rate limited",
                        bundle: .module
                    )
                )
            )
        }

        if let summary = friendlySummary(from: failure) {
            return .unavailable(failure.remapped(summary: summary))
        }

        return result
    }

    static func isUnsupportedModelFailure(_ failure: LumiLLMFailureDetail) -> Bool {
        if failure.reason == .unsupportedModel {
            return true
        }
        return isUnsupportedModelResponse(combinedText(from: failure))
    }

    static func isUnsupportedModelResponse(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("not supported model") || lower.contains("unsupported model") {
            return true
        }
        if lower.contains("model_not_found") || lower.contains("model not found") {
            return true
        }
        if lower.contains("invalid model") || lower.contains("unknown model") {
            return true
        }
        if lower.contains("param incorrect"), lower.contains("model") {
            return true
        }
        return false
    }

    static func isInvalidAPIKeyFailure(_ failure: LumiLLMFailureDetail) -> Bool {
        if failure.httpStatusCode == 401 {
            return true
        }
        let lower = combinedText(from: failure).lowercased()
        return lower.contains("invalid_api_key")
            || lower.contains("invalid api key")
            || lower.contains("incorrect api key")
            || lower.contains("api key not valid")
    }

    static func isQuotaExhaustedFailure(_ failure: LumiLLMFailureDetail) -> Bool {
        if failure.httpStatusCode == 429 {
            return true
        }
        let lower = combinedText(from: failure).lowercased()
        return lower.contains("quota")
            || lower.contains("rate limit")
            || lower.contains("too many requests")
    }

    static func isUnsupportedModelError(_ error: Error) -> Bool {
        if case let HTTPClientError.httpError(_, message) = error {
            return isUnsupportedModelResponse(message)
        }
        return isUnsupportedModelFailure(LLMFailureDetailResolver.resolve(from: error))
    }

    private static func combinedText(from failure: LumiLLMFailureDetail) -> String {
        [failure.summary, failure.transportDetails]
            .compactMap { $0 }
            .joined(separator: "\n")
    }

    private static func friendlySummary(from failure: LumiLLMFailureDetail) -> String? {
        for source in [failure.summary, failure.transportDetails].compactMap({ $0 }) {
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("{"), let message = parsedAPIErrorMessage(from: trimmed) {
                let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    return cleaned
                }
                continue
            }

            if !trimmed.hasPrefix("{") {
                return trimmed
            }
        }

        if let statusCode = failure.httpStatusCode {
            let template = LumiPluginLocalization.string(
                "Request failed (HTTP %d)",
                bundle: .module
            )
            return String(format: template, locale: Locale.current, statusCode)
        }

        return nil
    }

    private static func parsedAPIErrorMessage(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else {
            return nil
        }

        if let message = error["message"] as? String {
            return message
        }
        if let message = error["msg"] as? String {
            return message
        }
        return nil
    }
}