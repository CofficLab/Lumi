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
    /// HTTP 错误（状态码 + 摘要）。
    case httpStatus(Int, String)
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
        case .httpStatus(let code, let summary):
            return "服务返回 HTTP \(code)：\(summary)"
        case .requestFailed(let details):
            return "请求失败：\(details)"
        case .decodingFailed(let details):
            return "响应解析失败：\(details)"
        }
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
