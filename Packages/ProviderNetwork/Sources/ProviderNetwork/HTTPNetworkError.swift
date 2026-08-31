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
            if let responseMessage {
                return "HTTP error \(statusCode) for '\(url.absoluteString)': \(responseMessage)"
            }
            return "HTTP error \(statusCode) for '\(url.absoluteString)'"
        }
        return "Network request to '\(url.absoluteString)' failed: \(underlyingDescription ?? "unknown error")"
    }

    /// Extract the actionable message from common JSON error envelopes without
    /// exposing the complete response body in a user-facing error.
    private var responseMessage: String? {
        guard let body, !body.isEmpty else { return nil }

        if let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String,
               !message.isEmpty {
                return message
            }
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
            if let detail = object["detail"] as? String, !detail.isEmpty {
                return detail
            }
        }

        guard let text = String(data: body, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return String(text.prefix(2_000))
    }
}
