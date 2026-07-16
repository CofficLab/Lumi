import Foundation

/// Anthropic 兼容供应商错误
public enum AnthropicCompatibleProviderError: Error, Equatable, LocalizedError {
    /// 响应中没有内容块
    case noContent
    /// API 返回错误
    case apiError(message: String)

    public var errorDescription: String? {
        switch self {
        case .noContent:
            "No content in response"
        case let .apiError(message):
            message
        }
    }
}
