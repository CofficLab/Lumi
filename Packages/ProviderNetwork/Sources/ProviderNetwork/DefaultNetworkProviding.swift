import Foundation

/// `NetworkProviding` 的默认实现，基于 URLSession。
///
/// 无状态、线程安全：`session` 为 `Sendable`，可安全跨线程调用。
/// 流式请求使用 `URLSession.bytes(for:)`，原始字节由调用方按协议（如 SSE）解析。
public final class DefaultNetworkProviding: NetworkProviding, @unchecked Sendable {
    private let session: URLSession

    public init(configuration: URLSessionConfiguration = .default) {
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - NetworkProviding

    public func request(_ request: HTTPRequest) async throws -> HTTPResponse {
        let urlRequest = makeURLRequest(from: request)
        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw HTTPNetworkError(url: request.url, underlyingDescription: "Non-HTTP response")
        }

        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                result[key] = value
            }
        }

        return HTTPResponse(
            statusCode: http.statusCode,
            headers: headers,
            body: data,
            url: request.url
        )
    }

    public func stream(
        _ request: HTTPRequest,
        onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        let urlRequest = makeURLRequest(from: request)
        let (bytes, response) = try await session.bytes(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw HTTPNetworkError(url: request.url, underlyingDescription: "Non-HTTP response")
        }

        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            if let key = pair.key as? String, let value = pair.value as? String {
                result[key] = value
            }
        }

        let metadata = HTTPResponseMetadata(
            statusCode: http.statusCode,
            headers: headers,
            url: request.url,
            mimeType: http.mimeType,
            expectedContentLength: http.expectedContentLength,
            textEncodingName: http.textEncodingName
        )
        await onResponse(metadata)

        var iterator = bytes.makeAsyncIterator()
        while let byte = try await iterator.next() {
            let shouldContinue = await onChunk(Data([byte]))
            if !shouldContinue { break }
        }
    }

    // MARK: - Helpers

    private func makeURLRequest(from request: HTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.allHTTPHeaderFields = request.headers
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout
        return urlRequest
    }
}
