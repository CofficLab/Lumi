import Foundation
import HttpKit
import LumiCoreKit
import LumiLLMProviderSupport

enum AvailabilityService {
    static func checkAvailability(
        provider: ZhipuProvider,
        model: String,
        scheduler: AvailabilityScheduler = .shared
    ) async -> LumiModelAvailabilityResult {
        await scheduler.run {
            await mapFriendlyFailureResult(
                await provider.checkAvailabilityUsingChatPing(model: model)
            )
        }
    }

    static func mapFriendlyFailureResult(
        _ result: LumiModelAvailabilityResult
    ) -> LumiModelAvailabilityResult {
        guard case .unavailable(let failure) = result else { return result }

        if isRateLimitedFailure(failure) {
            return .unavailable(
                failure.remapped(
                    summary: LumiPluginLocalization.string(
                        "Zhipu quota exhausted or rate limited",
                        bundle: .module
                    )
                )
            )
        }

        return result
    }

    static func isRateLimitedFailure(_ failure: LumiLLMFailureDetail) -> Bool {
        if failure.httpStatusCode == 429 {
            return true
        }

        let lower = combinedText(from: failure).lowercased()
        return lower.contains("rate limit")
            || lower.contains("too many requests")
            || lower.contains("quota")
    }

    static func isRateLimitedError(_ error: Error) -> Bool {
        if case let HTTPClientError.httpError(statusCode, _) = error, statusCode == 429 {
            return true
        }
        return isRateLimitedFailure(LumiLLMFailureDetailResolver.resolve(from: error))
    }

    private static func combinedText(from failure: LumiLLMFailureDetail) -> String {
        [failure.summary, failure.transportDetails]
            .compactMap { $0 }
            .joined(separator: "\n")
    }
}
