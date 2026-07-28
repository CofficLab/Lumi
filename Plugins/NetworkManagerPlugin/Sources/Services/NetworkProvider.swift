import Foundation
import LumiKernel

/// 基于 URLSession 的 NetworkProviding 实现
@MainActor
public final class NetworkProvider: NetworkProviding {
    private let session: URLSession
    private let exchangeStore: HTTPExchangeStore?

    public init(session: URLSession = .shared, exchangeStore: HTTPExchangeStore? = nil) {
        self.session = session
        self.exchangeStore = exchangeStore
    }

    // MARK: - NetworkProviding

    public func request(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout

        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let startedAt = Date()
        let record = exchangeStore?.begin(request: urlRequest, startedAt: startedAt)
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            exchangeStore?.finish(record, error: error)
            throw HTTPNetworkError(
                url: request.url,
                underlyingDescription: error.localizedDescription
            )
        } catch {
            exchangeStore?.finish(record, error: error)
            throw HTTPNetworkError(
                url: request.url,
                underlyingDescription: error.localizedDescription
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            let error = HTTPNetworkError(url: request.url, body: data, underlyingDescription: "Invalid response")
            exchangeStore?.finish(record, response: response, body: data, error: error)
            throw error
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            let headers = Self.headers(from: httpResponse)
            let detailedError = HTTPNetworkError(
                url: request.url,
                statusCode: httpResponse.statusCode,
                headers: headers,
                body: data
            )
            exchangeStore?.finish(record, response: httpResponse, body: data, error: detailedError)
            throw detailedError
        }

        exchangeStore?.finish(record, response: httpResponse, body: data)

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: Self.headers(from: httpResponse),
            body: data,
            url: request.url
        )
    }

    public func stream(
        _ request: HTTPRequest,
        onResponse: @Sendable @escaping (HTTPResponseMetadata) async -> Void,
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let startedAt = Date()
        let record = exchangeStore?.begin(request: urlRequest, startedAt: startedAt)
        var receivedBody = Data()
        var response: URLResponse?

        do {
            let (bytes, urlResponse) = try await session.bytes(for: urlRequest)
            response = urlResponse
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                let error = HTTPNetworkError(url: request.url, underlyingDescription: "Invalid response")
                exchangeStore?.finish(record, response: urlResponse, body: receivedBody, error: error)
                throw error
            }

            let headers = Self.headers(from: httpResponse)
            await onResponse(HTTPResponseMetadata(
                statusCode: httpResponse.statusCode,
                headers: headers,
                url: httpResponse.url ?? request.url,
                mimeType: httpResponse.mimeType,
                expectedContentLength: httpResponse.expectedContentLength,
                textEncodingName: httpResponse.textEncodingName
            ))

            var chunk = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                chunk.append(byte)
                receivedBody.append(byte)
                if chunk.count >= 16 * 1024 {
                    let shouldContinue = await onChunk(chunk)
                    chunk.removeAll(keepingCapacity: true)
                    if !shouldContinue { break }
                }
            }
            if !chunk.isEmpty {
                _ = await onChunk(chunk)
            }

            if !(200..<300).contains(httpResponse.statusCode) {
                throw HTTPNetworkError(
                    url: request.url,
                    statusCode: httpResponse.statusCode,
                    headers: headers,
                    body: receivedBody
                )
            }
            exchangeStore?.finish(record, response: httpResponse, body: receivedBody)
        } catch is CancellationError {
            exchangeStore?.finish(record, response: response, body: receivedBody, error: CancellationError())
            throw CancellationError()
        } catch let error as HTTPNetworkError {
            exchangeStore?.finish(record, response: response, body: receivedBody, error: error)
            throw error
        } catch {
            let networkError = HTTPNetworkError(
                url: request.url,
                body: receivedBody,
                underlyingDescription: error.localizedDescription
            )
            exchangeStore?.finish(record, response: response, body: receivedBody, error: networkError)
            throw networkError
        }
    }

    private static func headers(from response: HTTPURLResponse) -> [String: String] {
        response.allHeaderFields.reduce(into: [String: String]()) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
    }
}
