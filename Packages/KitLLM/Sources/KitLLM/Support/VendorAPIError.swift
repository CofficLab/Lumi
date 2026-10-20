import Foundation

/// 供应商承载层的错误类型。
public enum VendorAPIError: Error, LocalizedError, Sendable, Equatable {
    /// 供应商未配置 API Key。
    case missingAPIKey(String)
    /// 读取 API Key 失败（Keychain 访问错误等）。
    case apiKeyAccessFailed(provider: String, details: String)
    /// baseURL 非法。
    case invalidBaseURL(String)
    /// 服务返回空响应。
    case emptyResponse
    /// 流式响应在收到协议终止信号前提前结束。
    case incompleteStream
    /// HTTP 错误（状态码 + 摘要 + 服务端建议的重试等待时间）。
    ///
    /// - Parameters:
    ///   - statusCode: HTTP 状态码。
    ///   - summary: 错误摘要（供 UI 展示与失败分类）。
    ///   - retryAfterSeconds: `Retry-After` 响应头给出的建议等待时间（秒）。
    ///     `nil` 表示服务端未给出建议，等待时长由本地指数退避决定。
    case httpStatus(statusCode: Int, summary: String, retryAfterSeconds: TimeInterval?)
    /// 底层网络/序列化错误。
    case requestFailed(String)
    /// 供应商返回的数据无法解析。
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "「\(provider)」尚未配置 API Key"
        case .apiKeyAccessFailed(let provider, let details):
            return "读取「\(provider)」API Key 失败：\(details)"
        case .invalidBaseURL(let url):
            return "无效的 API 地址：\(url)"
        case .emptyResponse:
            return "服务返回了空响应"
        case .incompleteStream:
            return "流式响应在收到结束信号前中断"
        case .httpStatus(let code, let summary, _):
            return "服务返回 HTTP \(code)：\(summary)"
        case .requestFailed(let details):
            return "请求失败：\(details)"
        case .decodingFailed(let details):
            return "响应解析失败：\(details)"
        }
    }
}

// MARK: - 便捷构造

extension VendorAPIError {
    /// 构造不带服务端退避建议的 HTTP 错误。
    ///
    /// 大多数调用点拿不到 `Retry-After`（响应头不存在、或错误并非由 HTTP
    /// 响应产生），用这个重载可以保持调用处简洁。
    public static func httpStatus(_ statusCode: Int, _ summary: String) -> VendorAPIError {
        .httpStatus(statusCode: statusCode, summary: summary, retryAfterSeconds: nil)
    }
}

// MARK: - LLMErrorRenderInfo

extension VendorAPIError: LLMErrorRenderInfo {
    /// 缺失 / 读取失败两类错误携带专属渲染类型，AgentLoop 透传后由
    /// 对应渲染器（API Key 输入卡）接管；其余错误走默认错误渲染。
    public var renderKind: String? {
        switch self {
        case .missingAPIKey:
            return LLMErrorRenderKind.apiKeyMissing
        case .apiKeyAccessFailed:
            return LLMErrorRenderKind.apiKeyAccessFailed
        default:
            return nil
        }
    }

    public var rawErrorDetail: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for: \(provider)"
        case .apiKeyAccessFailed(_, let details):
            return details
        default:
            return nil
        }
    }
}
