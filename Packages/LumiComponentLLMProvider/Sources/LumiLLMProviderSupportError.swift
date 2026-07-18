import Foundation
import LumiComponentMessage

/// LLM 供应商层的统一错误类型。
///
/// 设计上放在 `LumiComponentLLMProvider`，供 `LumiLLMProvider` 协议默认实现直接抛出；
/// HTTP 流式处理、BaseURL 校验等高级功能在 `LumiCoreKit` 中实现，可直接复用本类型。
public enum LumiLLMProviderSupportError: LocalizedError, LumiLLMErrorDispositionProviding {
    case emptyConversation
    case invalidBaseURL(String)
    case missingAPIKey(String)
    case allEndpointsFailed
    case streamingFailed(String)
    case emptyResponse

    public var llmErrorDisposition: LumiLLMErrorDisposition {
        switch self {
        case .emptyConversation, .invalidBaseURL, .missingAPIKey:
            return .nonRetryable
        case .allEndpointsFailed, .streamingFailed, .emptyResponse:
            return .retryable()
        }
    }

    public var errorDescription: String? {
        switch self {
        case .emptyConversation:
            return "空对话"
        case .invalidBaseURL(let url):
            return "无效的 Base URL：\(url)"
        case .missingAPIKey(let name):
            return "缺少 API Key：\(name)"
        case .allEndpointsFailed:
            return "所有端点均失败"
        case .streamingFailed(let details):
            return "流式请求失败：\(details)"
        case .emptyResponse:
            return "LLM 返回了空响应"
        }
    }
}
