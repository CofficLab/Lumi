import Foundation
import LumiKernel

/// 基于 URLSession 的 NetworkProviding 实现
@MainActor
public final class NetworkProvider: NetworkProviding {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
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

        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            throw LumiKernelError.networkRequestFailed(
                url: request.url.absoluteString,
                reason: error.localizedDescription
            )
        } catch {
            throw LumiKernelError.networkRequestFailed(
                url: request.url.absoluteString,
                reason: error.localizedDescription
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LumiKernelError.networkInvalidResponse(url: request.url.absoluteString)
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            throw LumiKernelError.networkHTTPError(
                url: request.url.absoluteString,
                statusCode: httpResponse.statusCode
            )
        }

        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                headers[keyString] = valueString
            }
        }

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: headers,
            body: data,
            url: request.url
        )
    }
}
