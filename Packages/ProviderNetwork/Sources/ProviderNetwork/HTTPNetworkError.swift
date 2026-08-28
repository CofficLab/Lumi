import Foundation

/// Structured transport failure retaining the server response whenever one exists.
///
/// 网络请求/响应相关的非错误类型（如 ``HTTPMethod``、``HTTPRequest``、
/// ``HTTPResponse``、``HTTPResponseMetadata``）保留在
/// `NetworkTypes.swift`,与本错误配套使用。
public struct HTTPNetworkError: Error, LocalizedError, Sendable {
    public let url: URL
    public let statusCode: Int?
    public let headers: [String: String]
    public let body: Data?
    public let underlyingDescription: String?
    public let underlyingCode: Int?

    public init(
        url: URL,
        statusCode: Int? = nil,
        headers: [String: String] = [:],
        body: Data? = nil,
        underlyingDescription: String? = nil,
        underlyingCode: Int? = nil
    ) {
        self.url = url
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.underlyingDescription = underlyingDescription
        self.underlyingCode = underlyingCode
    }

    public var errorDescription: String? {
        if let statusCode {
            return "HTTP error \(statusCode) for '\(url.absoluteString)'"
        }
        return "Network request to '\(url.absoluteString)' failed: \(underlyingDescription ?? "unknown error")"
    }
}
