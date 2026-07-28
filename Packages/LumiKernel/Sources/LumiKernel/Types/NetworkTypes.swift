import Foundation

// MARK: - HTTP Request Types

/// HTTP 请求方法
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

/// HTTP 请求配置
public struct HTTPRequest: Sendable {
    public let url: URL
    public let method: HTTPMethod
    public let headers: [String: String]
    public let body: Data?
    public let timeout: TimeInterval

    public init(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

/// HTTP 响应
public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data
    public let url: URL

    public var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }

    public var bodyString: String? {
        String(data: body, encoding: .utf8)
    }

    public init(statusCode: Int, headers: [String: String], body: Data, url: URL) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.url = url
    }
}
