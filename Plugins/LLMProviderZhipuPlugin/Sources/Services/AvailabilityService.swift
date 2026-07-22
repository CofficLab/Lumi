import Foundation
import HttpKit
import LLMKit
import LumiKernel
import LumiKernel
import LumiLLMProviderSupport

enum AvailabilityService {
    private static let cache = AvailabilityDiskCache(pluginName: "LLMProviderZhipuPlugin")

    static func checkAvailability(
        model: String,
        scheduler: AvailabilityScheduler = .shared,
        check: @Sendable @escaping (String) async -> LumiModelAvailabilityResult
    ) async -> LumiModelAvailabilityResult {
        // 优先读磁盘缓存
        if let cached = cache.read(model: model),
           Date().timeIntervalSince(cached.timestamp) < cache.cacheInterval {
            return cached.result
        }

        let result = await scheduler.run {
            await mapFriendlyFailureResult(
                await check(model)
            )
        }

        cache.write(model: model, result: result, timestamp: Date())
        return result
    }

    static func mapFriendlyFailureResult(
        _ result: LumiModelAvailabilityResult
    ) -> LumiModelAvailabilityResult {
        guard case .unavailable(let failure) = result else { return result }

        guard let summary = displaySummary(from: failure) else { return result }

        return .unavailable(failure.remapped(summary: summary))
    }

    static func displaySummary(from failure: LumiLLMFailureDetail) -> String? {
        if let message = apiErrorMessage(from: failure) {
            return message
        }

        if isRateLimitedFailure(failure) {
            return LumiPluginLocalization.string(
                "Zhipu quota exhausted or rate limited",
                bundle: .module
            )
        }

        return nil
    }

    static func apiErrorMessage(from failure: LumiLLMFailureDetail) -> String? {
        for source in [failure.transportDetails, failure.summary].compactMap({ $0 }) {
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("{"), let message = parsedAPIErrorMessage(from: trimmed) {
                return message
            }
        }
        return nil
    }

    static func isRateLimitedFailure(_ failure: LumiLLMFailureDetail) -> Bool {
        if failure.httpStatusCode == 429 {
            return true
        }

        let lower = combinedText(from: failure).lowercased()
        return lower.contains("rate limit")
            || lower.contains("rate_limit")
            || lower.contains("too many requests")
            || lower.contains("quota")
    }

    static func isRateLimitedError(_ error: Error) -> Bool {
        if case let HTTPClientError.httpError(statusCode, _) = error, statusCode == 429 {
            return true
        }
        return isRateLimitedFailure(LumiLLMFailureDetailResolver.resolve(from: error))
    }

    static func parsedAPIErrorMessage(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let error = json["error"] as? [String: Any] {
            if let message = error["message"] as? String {
                let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            if let message = error["msg"] as? String {
                let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }

        if let message = json["message"] as? String {
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }

        return nil
    }

    private static func combinedText(from failure: LumiLLMFailureDetail) -> String {
        [failure.summary, failure.transportDetails]
            .compactMap { $0 }
            .joined(separator: "\n")
    }
}
