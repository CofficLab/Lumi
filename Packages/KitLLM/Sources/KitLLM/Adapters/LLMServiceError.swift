import Foundation

/// `LLMService` 及其配置校验可能产生的唯一错误类型。
public enum LLMServiceError: Error, LocalizedError, Equatable {
    // MARK: - 不可重试判断

    /// 配置类错误（API Key 未配置、供应商未找到等）属于确定性失败，不应重试。
    public var isNonRetryable: Bool {
        switch self {
        case .apiKeyEmpty, .modelEmpty, .providerIdEmpty,
             .temperatureOutOfRange, .maxTokensInvalid,
             .providerNotFound, .invalidBaseURL, .cancelled:
            return true
        case .requestFailed:
            return false
        }
    }

    // MARK: - 配置校验（`LLMConfig.validate()`）

    case apiKeyEmpty
    case modelEmpty
    case providerIdEmpty
    case temperatureOutOfRange(Double)
    case maxTokensInvalid(Int)

    // MARK: - 服务

    /// 注册表中不存在对应 `providerId` 的实现。
    case providerNotFound(providerId: String)
    /// 供应商返回的 Base URL 无法解析为 `URL`。
    case invalidBaseURL(String)
    /// 任务被取消（如 `Task` 取消）。
    case cancelled
    /// 远程 API、流式解析、本地模型加载/就绪、或构建请求体失败等（使用用户可读文案）。
    /// statusCode 为可选的 HTTP 状态码，仅在 HTTP 请求失败时提供。
    case requestFailed(String, statusCode: Int? = nil)

    public var errorDescription: String? {
        switch self {
        case .apiKeyEmpty:
            return "API Key cannot be empty"
        case .modelEmpty:
            return "Model name cannot be empty"
        case .providerIdEmpty:
            return "Provider ID cannot be empty"
        case let .temperatureOutOfRange(v):
            return "Temperature should be between 0 and 2, current: \(v)"
        case let .maxTokensInvalid(v):
            return "Max tokens should be greater than 0, current: \(v)"
        case let .providerNotFound(providerId):
            return "Provider not found: \(providerId)"
        case let .invalidBaseURL(string):
            return "Invalid Base URL: \(string)"
        case .cancelled:
            return "Cancelled"
        case let .requestFailed(message, _):
            return message
        }
    }
}
