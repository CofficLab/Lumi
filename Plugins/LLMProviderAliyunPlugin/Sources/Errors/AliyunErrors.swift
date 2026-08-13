import Foundation
import KernelLumi

enum AliyunProviderError: LocalizedError, LumiLLMErrorDispositionProviding {
    case invalidRequest(String)
    case invalidResponse(String)
    case api(String)
    case maxTokensExceeded(Int?)

    var errorDescription: String? {
        switch self {
        case let .invalidRequest(value): return value
        case let .invalidResponse(value): return value
        case let .api(value): return value
        case let .maxTokensExceeded(outputTokens):
            let detail = outputTokens.map { "(\($0) tokens)" } ?? ""
            return "Aliyun hit the max_tokens limit \(detail) before producing any visible reply. Increase max_tokens and retry."
        }
    }

    var statusCode: Int? { nil }

    var llmErrorDisposition: LumiLLMErrorDisposition {
        switch self {
        case .api: .retryable()
        case .invalidRequest, .invalidResponse, .maxTokensExceeded: .nonRetryable
        }
    }
}
