import Foundation

// MARK: - Network Capability Protocol

/// 网络请求能力协议
///
/// 提供 HTTP 请求功能，支持 GET/POST/PUT/DELETE 等方法。
/// 由具体实现包提供（可基于 URLSession 或其他网络库实现）。
///
/// 协议刻意 **不** 标 `@MainActor`：流式请求(`stream`)的 SSE 字节循环和 HTTP
/// 交换记录写入都不应占用主线程。具体实现(`DefaultNetworkProviding`)
/// 是无状态、线程安全的(`session` 是 `Sendable`),因此所有方法都是 nonisolated。
/// 调用方(各 LLM provider)本就在后台 `await`,去掉 `@MainActor` 后它们不再
/// 被迫 hop 到主线程。
public protocol NetworkProviding: AnyObject, Sendable {
    /// 发起同步请求并返回响应
    ///
    /// - Parameter request: HTTP 请求配置
    /// - Returns: HTTP 响应
    /// - Throws: 网络错误或 HTTP 错误状态码
    func request(_ request: HTTPRequest) async throws -> HTTPResponse

    /// 发起流式请求。回调收到的是底层原始字节，协议层（例如 SSE）由调用方解析。
    /// `onResponse` 会在收到响应头后、收到第一个 body chunk 前调用。
    /// 返回 false 会停止读取 body。
    func stream(
        _ request: HTTPRequest,
        onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws

    /// 发起 GET 请求
    ///
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - headers: 可选的请求头
    ///   - timeout: 超时时间（秒）
    /// - Returns: HTTP 响应
    /// - Throws: 网络错误或 HTTP 错误状态码
    func get(url: URL, headers: [String: String], timeout: TimeInterval) async throws -> HTTPResponse

    /// 发起 POST 请求
    ///
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - body: 请求体数据
    ///   - contentType: Content-Type 头值
    ///   - headers: 可选的请求头
    ///   - timeout: 超时时间（秒）
    /// - Returns: HTTP 响应
    /// - Throws: 网络错误或 HTTP 错误状态码
    func post(
        url: URL,
        body: Data,
        contentType: String,
        headers: [String: String],
        timeout: TimeInterval
    ) async throws -> HTTPResponse

    /// 发起 JSON 请求（自动编码/解码）
    ///
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - method: HTTP 方法
    ///   - body: 编码到请求体的 Encodable 对象
    ///   - headers: 可选的请求头（Content-Type 会被自动设置）
    ///   - timeout: 超时时间（秒）
    /// - Returns: 解码后的响应体
    /// - Throws: 网络错误、编码错误或 HTTP 错误状态码
    func json<T: Sendable, R: Sendable>(
        url: URL,
        method: HTTPMethod,
        body: T,
        headers: [String: String],
        timeout: TimeInterval
    ) async throws -> R where T: Encodable, R: Decodable

    /// 下载文件到指定位置
    ///
    /// - Parameters:
    ///   - url: 下载 URL
    ///   - destination: 本地保存路径
    ///   - headers: 可选的请求头
    ///   - timeout: 超时时间（秒）
    /// - Returns: 下载文件的本地 URL
    /// - Throws: 网络错误或文件系统错误
    func download(
        from url: URL,
        to destination: URL,
        headers: [String: String],
        timeout: TimeInterval
    ) async throws -> URL
}

// MARK: - Default Implementations

public extension NetworkProviding {
    /// 默认 GET 实现
    func get(url: URL, headers: [String: String] = [:], timeout: TimeInterval = 30) async throws -> HTTPResponse {
        try await request(HTTPRequest(url: url, method: .get, headers: headers, timeout: timeout))
    }

    /// 默认 POST 实现
    func post(
        url: URL,
        body: Data,
        contentType: String = "application/json",
        headers: [String: String] = [:],
        timeout: TimeInterval = 30
    ) async throws -> HTTPResponse {
        var allHeaders = headers
        allHeaders["Content-Type"] = contentType
        return try await request(HTTPRequest(url: url, method: .post, headers: allHeaders, body: body, timeout: timeout))
    }

    /// 默认 JSON 实现
    func json<T: Sendable, R: Sendable>(
        url: URL,
        method: HTTPMethod,
        body: T,
        headers: [String: String] = [:],
        timeout: TimeInterval = 30
    ) async throws -> R where T: Encodable, R: Decodable {
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(body)

        var allHeaders = headers
        allHeaders["Content-Type"] = "application/json"
        allHeaders["Accept"] = "application/json"

        let response = try await request(
            HTTPRequest(url: url, method: method, headers: allHeaders, body: bodyData, timeout: timeout)
        )

        let decoder = JSONDecoder()
        return try decoder.decode(R.self, from: response.body)
    }

    /// 默认 download 实现
    func download(
        from url: URL,
        to destination: URL,
        headers: [String: String] = [:],
        timeout: TimeInterval = 300
    ) async throws -> URL {
        let response = try await get(url: url, headers: headers, timeout: timeout)

        try response.body.write(to: destination)
        return destination
    }
}
