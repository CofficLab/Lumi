import Foundation

/// 供应商对单次失败给出的重试决策。
public struct ProviderRetryDecision: Sendable, Equatable {
    public let shouldRetry: Bool
    public let delaySeconds: Double?

    public init(shouldRetry: Bool, delaySeconds: Double? = nil) {
        self.shouldRetry = shouldRetry
        self.delaySeconds = delaySeconds
    }

    public static let doNotRetry = ProviderRetryDecision(shouldRetry: false)
}

/// 通用 HTTP 重试判断（OpenAI / Anthropic 兼容供应商可复用）。
public enum ProviderRetryPolicy {
    public static func decision(
        statusCode: Int?,
        retryAfter: TimeInterval?,
        attempt: Int,
        maxAttempts: Int
    ) -> ProviderRetryDecision {
        guard attempt < maxAttempts else { return .doNotRetry }

        if let retryAfter, retryAfter > 0 {
            return ProviderRetryDecision(shouldRetry: true, delaySeconds: retryAfter)
        }

        if statusCode == 429 {
            return ProviderRetryDecision(shouldRetry: true, delaySeconds: nil)
        }

        if let statusCode, (500 ... 599).contains(statusCode) {
            return ProviderRetryDecision(shouldRetry: true, delaySeconds: nil)
        }

        return .doNotRetry
    }

    public static func decision(forNetworkError error: Error, attempt: Int, maxAttempts: Int) -> ProviderRetryDecision {
        guard attempt < maxAttempts else { return .doNotRetry }
        let nsError = error as NSError
        let retryableCodes: [Int] = [
            NSURLErrorTimedOut,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
        ]
        if retryableCodes.contains(nsError.code) {
            return ProviderRetryDecision(shouldRetry: true, delaySeconds: nil)
        }
        return .doNotRetry
    }
}
