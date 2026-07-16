import Foundation

/// Anthropic 兼容供应商配置
///
/// 用于配置 Anthropic API 兼容的供应商，支持自定义认证头、API 版本等。
/// 兼容供应商包括：Anthropic 原生 API、阿里云 DashScope 等。
public struct AnthropicCompatibleProviderConfiguration: Sendable, Equatable {
    /// API 基础 URL
    public let baseURL: String

    /// 主入口不可用时的备用 URL 列表
    public let fallbackBaseURLs: [String]

    /// 额外的 HTTP 请求头
    public let additionalHeaders: [String: String]

    /// Anthropic API 版本
    public let apiVersion: String

    /// 默认最大输出 token 数
    public let defaultMaxTokens: Int

    public init(
        baseURL: String,
        fallbackBaseURLs: [String] = [],
        additionalHeaders: [String: String] = [:],
        apiVersion: String = "2023-06-01",
        defaultMaxTokens: Int = 8192
    ) {
        self.baseURL = baseURL
        self.fallbackBaseURLs = fallbackBaseURLs
        self.additionalHeaders = additionalHeaders
        self.apiVersion = apiVersion
        self.defaultMaxTokens = defaultMaxTokens
    }
}
