import Foundation
import KernelLumi
@testable import AppStoreConnectPlugin

/// Keeps URLProtocol-based transport mocking in the test target while production
/// App Store Connect code depends exclusively on Kernel's network capability.
private final class URLSessionTestNetworkProvider: NetworkProviding, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func request(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse else {
            throw HTTPNetworkError(url: request.url, body: data, underlyingDescription: "Invalid response")
        }
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw HTTPNetworkError(
                url: request.url,
                statusCode: response.statusCode,
                headers: headers,
                body: data
            )
        }
        return HTTPResponse(statusCode: response.statusCode, headers: headers, body: data, url: request.url)
    }

    func stream(
        _ request: HTTPRequest,
        onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        let response = try await self.request(request)
        await onResponse(HTTPResponseMetadata(
            statusCode: response.statusCode,
            headers: response.headers,
            url: response.url
        ))
        _ = await onChunk(response.body)
    }
}

extension ConnectClient {
    convenience init(
        credentialsProvider: @escaping @Sendable () -> AppStoreConnectCredentials,
        session: URLSession,
        cache: ConnectAPICache = .shared
    ) {
        self.init(
            credentialsProvider: credentialsProvider,
            network: URLSessionTestNetworkProvider(session: session),
            cache: cache
        )
    }
}

extension ScreenshotImageCache {
    init(
        rootDirectory: URL,
        session: URLSession,
        diskStore: ScreenshotCacheDiskStore? = nil
    ) {
        self.init(
            rootDirectory: rootDirectory,
            network: URLSessionTestNetworkProvider(session: session),
            diskStore: diskStore
        )
    }
}
