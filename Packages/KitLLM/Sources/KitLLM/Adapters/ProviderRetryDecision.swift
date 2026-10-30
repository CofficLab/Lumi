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

        // 只有 429（限流）与 5xx（含 529 过载）可重试。
        //
        // `Retry-After` 只影响**等待时长**，绝不扩大可重试范围：401/403/400
        // 即使带了 `Retry-After` 也不该重试——重发同样的请求只会重复失败，
        // 认证失败重试甚至可能触发账号风控。
        //
        // （早期实现把 `retryAfter` 判断放在状态码判断之前，等于让任意状态码
        // 都能靠一个响应头被判定为可重试。此前生产路径恒传 `nil` 使其成为
        // 死代码，接入真实 `Retry-After` 后必须先修掉。）
        guard let statusCode, isRetryableStatus(statusCode) else { return .doNotRetry }

        if let retryAfter, retryAfter > 0 {
            return ProviderRetryDecision(shouldRetry: true, delaySeconds: retryAfter)
        }

        // 没有服务端建议：等待时长交由本地带抖动的指数退避决定。
        return ProviderRetryDecision(shouldRetry: true, delaySeconds: nil)
    }

    /// 状态码是否属于可重试区间。
    static func isRetryableStatus(_ statusCode: Int) -> Bool {
        statusCode == 429 || (500 ... 599).contains(statusCode)
    }

    public static func decision(forNetworkError error: Error, attempt: Int, maxAttempts: Int) -> ProviderRetryDecision {
        guard attempt < maxAttempts else { return .doNotRetry }
        let nsError = error as NSError
        let retryableCodes: [Int] = [
            NSURLErrorTimedOut,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorSecureConnectionFailed,
        ]
        if retryableCodes.contains(nsError.code) {
            return ProviderRetryDecision(shouldRetry: true, delaySeconds: nil)
        }
        return .doNotRetry
    }
}
