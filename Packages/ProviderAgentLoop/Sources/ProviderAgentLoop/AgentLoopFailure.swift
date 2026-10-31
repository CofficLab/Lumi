import Foundation
import KitLLM

/// AgentLoop 最终失败时的结构化错误快照。
///
/// 失败原因由 AgentLoop 统一归类，消费方（例如自动重试插件）不需要
/// 通过本地化后的错误字符串做脆弱的文本匹配。
public struct AgentLoopFailure: Sendable, Equatable, Codable {
    public enum Kind: String, Sendable, Equatable, Codable {
        case network
        case timeout
        case rateLimited
        case server
        case incompleteStream
        case decoding
        case emptyResponse
        case authentication
        case configuration
        case contextLimit
        case request
        case unknown
    }

    public let kind: Kind
    public let message: String
    public let providerID: String?
    public let modelName: String?
    public let httpStatusCode: Int?
    /// 服务端建议的重试等待时间（秒），来自 `Retry-After` 响应头。
    ///
    /// `nil` 表示服务端未给出建议。回合级重试必须遵守它：回合重启是一次
    /// **全新**的请求，仍需满足服务端要求的静默窗口，否则刚等完传输层的
    /// 退避就立刻再打一次，等于没退避。
    public let retryAfterSeconds: TimeInterval?

    public init(
        kind: Kind,
        message: String,
        providerID: String? = nil,
        modelName: String? = nil,
        httpStatusCode: Int? = nil,
        retryAfterSeconds: TimeInterval? = nil
    ) {
        self.kind = kind
        self.message = message
        self.providerID = providerID
        self.modelName = modelName
        self.httpStatusCode = httpStatusCode
        self.retryAfterSeconds = retryAfterSeconds
    }

    /// 是否适合由上层策略自动重试。
    ///
    /// `.emptyResponse` 可重试：模型偶发返回空终态响应属于瞬时异常，
    /// 由自动重试插件带时间线提示重启回合。
    public var isRetryable: Bool {
        switch kind {
        case .network, .timeout, .rateLimited, .server, .incompleteStream, .decoding, .emptyResponse:
            return true
        case .authentication, .configuration, .contextLimit, .request, .unknown:
            return false
        }
    }

    /// 将供应商错误归一为 AgentLoop 层可消费的失败类型。
    public static func from(
        error: Error,
        providerID: String? = nil,
        modelName: String? = nil
    ) -> AgentLoopFailure {
        let message = error.localizedDescription

        if let kind = Self.kind(forSystemNetworkError: error) {
            return AgentLoopFailure(
                kind: kind,
                message: message,
                providerID: providerID,
                modelName: modelName
            )
        }

        if let vendorError = error as? VendorAPIError {
            switch vendorError {
            case .missingAPIKey, .apiKeyAccessFailed:
                return AgentLoopFailure(
                    kind: .authentication,
                    message: message,
                    providerID: providerID,
                    modelName: modelName
                )
            case .invalidBaseURL:
                return AgentLoopFailure(
                    kind: .configuration,
                    message: message,
                    providerID: providerID,
                    modelName: modelName
                )
            case .emptyResponse:
                return AgentLoopFailure(
                    kind: .emptyResponse,
                    message: message,
                    providerID: providerID,
                    modelName: modelName
                )
            case .incompleteStream:
                return AgentLoopFailure(
                    kind: .incompleteStream,
                    message: message,
                    providerID: providerID,
                    modelName: modelName
                )
            case .httpStatus(let statusCode, let summary, let retryAfterSeconds):
                return AgentLoopFailure(
                    kind: Self.kind(forHTTPStatus: statusCode, summary: summary),
                    message: message,
                    providerID: providerID,
                    modelName: modelName,
                    httpStatusCode: statusCode,
                    retryAfterSeconds: retryAfterSeconds
                )
            case .requestFailed(let details):
                return AgentLoopFailure(
                    kind: Self.kind(forRequestFailure: details),
                    message: message,
                    providerID: providerID,
                    modelName: modelName
                )
            case .decodingFailed:
                return AgentLoopFailure(
                    kind: .decoding,
                    message: message,
                    providerID: providerID,
                    modelName: modelName
                )
            }
        }

        // 个别 Provider（如 Codex CLI）在空输出时抛 LLMProviderError.emptyResponse；
        // 统一归类为 emptyResponse，纳入自动重试。
        if let providerError = error as? LLMProviderError,
           case .emptyResponse = providerError {
            return AgentLoopFailure(
                kind: .emptyResponse,
                message: message,
                providerID: providerID,
                modelName: modelName
            )
        }

        return AgentLoopFailure(
            kind: .unknown,
            message: message,
            providerID: providerID,
            modelName: modelName
        )
    }

    private static func kind(forSystemNetworkError error: Error) -> Kind? {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return nil }
        return nsError.code == NSURLErrorTimedOut ? .timeout : .network
    }

    private static func kind(forHTTPStatus statusCode: Int, summary: String) -> Kind {
        switch statusCode {
        case 408, 504:
            return .timeout
        case 425, 429:
            return .rateLimited
        case 500...599:
            return .server
        case 401, 403:
            return .authentication
        default:
            if isContextLimit(summary) {
                return .contextLimit
            }
            return .request
        }
    }

    private static func kind(forRequestFailure details: String) -> Kind {
        let normalized = details.lowercased()
        if normalized.contains("timed out")
            || normalized.contains("timeout")
            || normalized.contains("timedout") {
            return .timeout
        }
        return .network
    }

    private static func isContextLimit(_ summary: String) -> Bool {
        let normalized = summary.lowercased()
        return normalized.contains("context")
            || normalized.contains("token limit")
            || normalized.contains("maximum token")
            || normalized.contains("too many tokens")
            || normalized.contains("prompt is too long")
    }
}
