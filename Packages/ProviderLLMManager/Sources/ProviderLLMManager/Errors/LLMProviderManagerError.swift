import Combine
import Foundation
import KitLLM

/// LLM Provider 管理器错误（ProviderLLMManager 自有错误，避免改动 ProviderLLM 的错误集）。
public enum LLMProviderManagerError: Error, LocalizedError, Sendable, Equatable {
    /// 注册时供应商声明的 `id` 为空。
    case emptyProviderID
    /// 指定 id 的供应商不存在。
    case providerNotFound(String)
    /// 没有任何已注册供应商（发送链路未配置）。
    case noProviderConfigured

    public var errorDescription: String? {
        switch self {
        case .emptyProviderID:
            return "LLM provider 声明的 id 为空"
        case let .providerNotFound(id):
            return "LLM provider 未注册: \(id)"
        case .noProviderConfigured:
            return "没有已注册的 LLM provider"
        }
    }
}
