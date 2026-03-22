import Foundation

/// `LLMService` 在解析配置之后、完成一次对话请求的过程中可能抛出的错误。
///
/// 配置校验（含 API Key 为空）由 `LLMConfig.validate()` 抛出 `LLMConfigValidationError`，不在此枚举中。
enum LLMServiceError: Error, LocalizedError, Equatable {
    /// 注册表中不存在对应 `providerId` 的实现。
    case providerNotFound(providerId: String)
    /// 供应商返回的 Base URL 无法解析为 `URL`。
    case invalidBaseURL(String)
    /// 远程 API、流式解析、或本地模型加载/就绪流程失败（使用已有用户可读文案）。
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .providerNotFound(let providerId):
            return "Provider not found: \(providerId)"
        case .invalidBaseURL(let string):
            return "Invalid Base URL: \(string)"
        case .requestFailed(let message):
            return message
        }
    }
}
