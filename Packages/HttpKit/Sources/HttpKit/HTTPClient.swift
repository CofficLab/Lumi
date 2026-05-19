import Foundation
import Security

public final class HTTPClient: @unchecked Sendable {
    private let session: URLSession
    private let tlsDelegate: TLSValidationDelegate

    public init(
        timeoutIntervalForRequest: TimeInterval = 300,
        timeoutIntervalForResource: TimeInterval = 600,
        configuration configure: ((URLSessionConfiguration) -> Void)? = nil
    ) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutIntervalForRequest
        configuration.timeoutIntervalForResource = timeoutIntervalForResource
        configure?(configuration)

        self.tlsDelegate = TLSValidationDelegate()
        self.session = URLSession(
            configuration: configuration,
            delegate: tlsDelegate,
            delegateQueue: nil
        )
    }

    public func sendJSONRequest(
        request: URLRequest,
        body: [String: Any]
    ) async throws -> Data {
        let (data, _) = try await sendJSONRequestWithResponse(request: request, body: body)
        return data
    }

    public func sendJSONRequestWithResponse(
        request: URLRequest,
        body: [String: Any]
    ) async throws -> (Data, HTTPURLResponse) {
        var mutableRequest = request
        mutableRequest.httpBody = try Self.encodeJSONObject(body)

        do {
            let (data, response) = try await session.data(for: mutableRequest)
            let httpResponse = try validateResponse(response, data: data)
            return (data, httpResponse)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HTTPClientError {
            throw error
        } catch {
            throw HTTPClientError.requestFailed(underlying: error)
        }
    }

    public func sendStreamingJSONRequest(
        request: URLRequest,
        body: [String: Any],
        timeoutInterval: TimeInterval = 300,
        onRequestStart: @Sendable @escaping (HTTPRequestMetadata) async -> Void = { _ in },
        onEvent: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        var mutableRequest = request
        mutableRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        mutableRequest.timeoutInterval = timeoutInterval

        let jsonData = try Self.encodeJSONObject(body)
        mutableRequest.httpBody = jsonData

        let metadata = HTTPRequestMetadata(
            requestId: UUID(),
            method: mutableRequest.httpMethod ?? HTTPMethod.post.rawValue,
            url: mutableRequest.url?.absoluteString ?? "unknown",
            requestHeaders: Self.sanitizeHeaders(mutableRequest.allHTTPHeaderFields ?? [:]),
            requestBodySizeBytes: jsonData.count,
            requestBodyPreview: String(data: jsonData, encoding: .utf8),
            sentAt: Date()
        )
        await onRequestStart(metadata)

        do {
            let (bytes, response) = try await session.bytes(for: mutableRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPClientError.invalidResponse
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                var errorData = Data()
                for try await byte in bytes {
                    errorData.append(byte)
                }
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw HTTPClientError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: errorMessage
                )
            }

            try await readServerSentEvents(from: bytes, onEvent: onEvent)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HTTPClientError {
            throw error
        } catch {
            throw HTTPClientError.requestFailed(underlying: error)
        }
    }

    public func validateResponse(_ response: URLResponse, data: Data) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            let errorMessage = """
            HTTP Error (\(httpResponse.statusCode))
            URL: \(response.url?.absoluteString ?? "Unknown")
            Response: \(errorString)
            """

            throw HTTPClientError.httpError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
        }

        return httpResponse
    }

    public static func sanitizeHeaders(_ headers: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in headers {
            result[key] = isSensitiveHeader(key) ? "***" : value
        }
        return result
    }

    public static func maskSensitiveValue(key: String, value: String) -> String {
        guard isSensitiveHeader(key) else { return value }

        if value.count <= 8 {
            return "\(value.prefix(2))***\(value.suffix(2))"
        }

        let prefix = value.prefix(4)
        let suffix = value.suffix(4)
        let stars = String(repeating: "*", count: max(3, value.count - 8))
        return "\(prefix)\(stars)\(suffix)"
    }

    private static func isSensitiveHeader(_ key: String) -> Bool {
        let lower = key.lowercased()
        return lower.contains("authorization")
            || lower.contains("api-key")
            || lower.hasSuffix("key")
            || lower.contains("token")
    }

    private static func encodeJSONObject(_ body: [String: Any]) throws -> Data {
        do {
            return try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw HTTPClientError.jsonSerializationFailed(underlying: error)
        }
    }

    private func readServerSentEvents(
        from bytes: URLSession.AsyncBytes,
        onEvent: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        var eventBuffer = Data()
        var lastBytes: [UInt8] = []

        for try await byte in bytes {
            try Task.checkCancellation()
            eventBuffer.append(byte)
            lastBytes.append(byte)
            if lastBytes.count > 4 {
                lastBytes.removeFirst(lastBytes.count - 4)
            }

            let hitLF = lastBytes.suffix(2).elementsEqual([0x0A, 0x0A])
            let hitCRLF = lastBytes.count >= 4 && lastBytes.suffix(4).elementsEqual([0x0D, 0x0A, 0x0D, 0x0A])

            if hitLF || hitCRLF {
                let delimiterLength = hitCRLF ? 4 : 2
                guard eventBuffer.count >= delimiterLength else {
                    eventBuffer.removeAll(keepingCapacity: true)
                    lastBytes.removeAll(keepingCapacity: true)
                    continue
                }

                let eventData = eventBuffer.dropLast(delimiterLength)
                eventBuffer.removeAll(keepingCapacity: true)
                lastBytes.removeAll(keepingCapacity: true)

                guard !eventData.isEmpty else { continue }
                let shouldContinue = await onEvent(Data(eventData))
                if !shouldContinue {
                    return
                }
            }
        }

        if !eventBuffer.isEmpty {
            _ = await onEvent(eventBuffer)
        }
    }
}

private final class TLSValidationDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)
        if isValid {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
