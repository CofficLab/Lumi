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

    public init(
        kind: Kind,
        message: String,
        providerID: String? = nil,
        modelName: String? = nil,
        httpStatusCode: Int? = nil
    ) {
        self.kind = kind
        self.message = message
        self.providerID = providerID
        self.modelName = modelName
        self.httpStatusCode = httpStatusCode
    }

    /// 是否适合由上层策略自动重试。
    public var isRetryable: Bool {
        switch kind {
        case .network, .timeout, .rateLimited, .server, .incompleteStream, .decoding:
            return true
        case .emptyResponse, .authentication, .configuration, .contextLimit, .request, .unknown:
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
            case .httpStatus(let statusCode, let summary):
                return AgentLoopFailure(
                    kind: Self.kind(forHTTPStatus: statusCode, summary: summary),
                    message: message,
                    providerID: providerID,
                    modelName: modelName,
                    httpStatusCode: statusCode
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

        return AgentLoopFailure(
            kind: .unknown,
            message: message,
            providerID: providerID,
            modelName: modelName
        )
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
