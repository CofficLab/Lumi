import Foundation
import SwiftData

/// LLM 请求日志模型（仅供 LLMRequestLoggerPlugin 使用）
@Model
final class LLMRequestLog {
    @Attribute(.unique) var id: UUID
    var timestamp: Date

    /// 供应商 ID，例如 "anthropic"、"openai"
    var providerId: String

    /// 模型名称，例如 "claude-3.7-sonnet"
    var model: String

    /// HTTP 方法（通常为 "POST"）
    var method: String

    /// 请求 URL 字符串
    var url: String

    /// HTTP 状态码（流式请求可为 nil）
    var statusCode: Int?

    /// 请求总耗时（毫秒）
    var durationMs: Double?

    /// 截断后的请求体（原始 JSON 字节前缀）
    var requestBodyPreview: Data?

    /// 截断后的响应体（原始 JSON 字节前缀）
    var responseBodyPreview: Data?

    /// 错误描述（若请求失败）
    var errorDescription: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        providerId: String,
        model: String,
        method: String,
        url: String,
        statusCode: Int? = nil,
        durationMs: Double? = nil,
        requestBodyPreview: Data? = nil,
        responseBodyPreview: Data? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.providerId = providerId
        self.model = model
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.durationMs = durationMs
        self.requestBodyPreview = requestBodyPreview
        self.responseBodyPreview = responseBodyPreview
        self.errorDescription = errorDescription
    }
}

