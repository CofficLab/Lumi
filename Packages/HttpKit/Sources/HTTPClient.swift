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
        onResponseReceived: @Sendable @escaping (HTTPURLResponse) async -> Void = { _ in },
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

            // Notify caller of response metadata (always, not just errors)
            await onResponseReceived(httpResponse)

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

    // MARK: - Generic Requests (No Body)

    /// 发送不含请求体的 HTTP 请求（适用于 GET、DELETE 等）。
    ///
    /// - Parameter request: 已配置好 URL、HTTP 方法、Header 的 URLRequest。
    /// - Returns: 响应体 Data。
    /// - Throws: `HTTPClientError`。
    public func sendRequest(
        request: URLRequest
    ) async throws -> Data {
        let (data, _) = try await sendRequestWithResponse(request: request)
        return data
    }

    /// 发送不含请求体的 HTTP 请求，同时返回 `HTTPURLResponse`。
    ///
    /// - Parameter request: 已配置好 URL、HTTP 方法、Header 的 URLRequest。
    /// - Returns: (响应体 Data, HTTPURLResponse) 元组。
    /// - Throws: `HTTPClientError`。
    public func sendRequestWithResponse(
        request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
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

    // MARK: - Generic Requests with Encodable Body

    /// 发送带 `Encodable` 请求体的 HTTP 请求。
    ///
    /// - Parameters:
    ///   - request: 已配置好 URL、HTTP 方法、Header 的 URLRequest。
    ///   - body: 遵循 `Encodable` 的请求体对象。
    /// - Returns: 响应体 Data。
    /// - Throws: `HTTPClientError`。
    public func sendEncodableRequest<B: Encodable>(
        request: URLRequest,
        body: B
    ) async throws -> Data {
        let (data, _) = try await sendEncodableRequestWithResponse(request: request, body: body)
        return data
    }

    /// 发送带 `Encodable` 请求体的 HTTP 请求，同时返回 `HTTPURLResponse`。
    ///
    /// - Parameters:
    ///   - request: 已配置好 URL、HTTP 方法、Header 的 URLRequest。
    ///   - body: 遵循 `Encodable` 的请求体对象。
    /// - Returns: (响应体 Data, HTTPURLResponse) 元组。
    /// - Throws: `HTTPClientError`。
    public func sendEncodableRequestWithResponse<B: Encodable>(
        request: URLRequest,
        body: B
    ) async throws -> (Data, HTTPURLResponse) {
        var mutableRequest = request
        mutableRequest.httpBody = try Self.encodeEncodable(body)

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

    // MARK: - Decodable Response

    /// 发送请求并自动将 JSON 响应解码为 `Decodable` 类型。
    ///
    /// - Parameters:
    ///   - request: 已配置好 URL、HTTP 方法、Header 的 URLRequest。
    ///   - responseType: 期望的响应类型。
    ///   - decoder: JSON 解码器（默认 `JSONDecoder()`）。
    /// - Returns: 解码后的对象。
    /// - Throws: `HTTPClientError`。
    public func sendDecodableRequest<T: Decodable>(
        request: URLRequest,
        as responseType: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let data = try await sendRequest(request: request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed(underlying: error)
        }
    }

    /// 发送带 `[String: Any]` 请求体的请求，并自动将 JSON 响应解码为 `Decodable` 类型。
    ///
    /// - Parameters:
    ///   - request: 已配置好 URL、HTTP 方法、Header 的 URLRequest。
    ///   - body: JSON 字典形式的请求体。
    ///   - responseType: 期望的响应类型。
    ///   - decoder: JSON 解码器（默认 `JSONDecoder()`）。
    /// - Returns: 解码后的对象。
    /// - Throws: `HTTPClientError`。
    public func sendJSONDecodableRequest<T: Decodable>(
        request: URLRequest,
        body: [String: Any],
        as responseType: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let data = try await sendJSONRequest(request: request, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed(underlying: error)
        }
    }

    /// 发送带 `Encodable` 请求体的请求，并自动将 JSON 响应解码为 `Decodable` 类型。
    ///
    /// - Parameters:
    ///   - request: 已配置好 URL、HTTP 方法、Header 的 URLRequest。
    ///   - body: 遵循 `Encodable` 的请求体对象。
    ///   - responseType: 期望的响应类型。
    ///   - decoder: JSON 解码器（默认 `JSONDecoder()`）。
    /// - Returns: 解码后的对象。
    /// - Throws: `HTTPClientError`。
    public func sendEncodableDecodableRequest<B: Encodable, T: Decodable>(
        request: URLRequest,
        body: B,
        as responseType: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let data = try await sendEncodableRequest(request: request, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HTTPClientError.decodingFailed(underlying: error)
        }
    }

    // MARK: - Send Data (No Response Body)

    /// 发送带原始 Data 请求体的 HTTP 请求（适用于 POST JSON 数据等）。
    ///
    /// - Parameters:
    ///   - request: 已配置好 URL、HTTP 方法、Header 的 URLRequest。
    ///   - body: 请求体 Data。
    /// - Returns: (响应体 Data, HTTPURLResponse) 元组。
    /// - Throws: `HTTPClientError`。
    public func sendDataRequestWithResponse(
        request: URLRequest,
        body: Data
    ) async throws -> (Data, HTTPURLResponse) {
        var mutableRequest = request
        mutableRequest.httpBody = body

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

    // MARK: - SSE Line-by-Line Streaming

    /// 发送流式请求，按 SSE 行级别解析每一行（`event:`、`data:`、`id:`、注释行）。
    ///
    /// 与 `sendStreamingJSONRequest` 不同，此方法将每个 SSE 事件的行内容逐行回调，
    /// 而非将整个事件块（`\n\n` 分隔）一次性回调。
    /// 适用于需要自行解析 `event:` / `data:` 字段的场景（如 MCP SSE 协议）。
    ///
    /// - Parameters:
    ///   - request: 已配置好 URL、HTTP 方法、Header 的 URLRequest。
    ///   - timeoutInterval: 超时时间（默认 300 秒）。
    ///   - onLine: 每行的回调。返回 `false` 停止读取。行内容已去除 `\r\n` / `\n` 尾部。
    /// - Throws: `HTTPClientError`。
    public func sendStreamingRequest(
        request: URLRequest,
        timeoutInterval: TimeInterval = 300,
        onLine: @Sendable @escaping (String) async -> Bool
    ) async throws {
        var mutableRequest = request
        mutableRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        mutableRequest.timeoutInterval = timeoutInterval

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

            // 手动按 SSE 行结束符分割行，保留空行（SSE 协议依赖空行分隔事件）。
            // bytes.lines 会跳过空行，不适合 SSE 场景。
            var lineBuffer = Data()
            var previousByteWasCR = false
            for try await byte in bytes {
                try Task.checkCancellation()
                if byte == UInt8(ascii: "\n") {
                    if previousByteWasCR {
                        previousByteWasCR = false
                        continue
                    }
                    let line = String(decoding: lineBuffer, as: UTF8.self)
                    lineBuffer.removeAll(keepingCapacity: true)
                    let shouldContinue = await onLine(line)
                    if !shouldContinue {
                        return
                    }
                } else if byte == UInt8(ascii: "\r") {
                    let line = String(decoding: lineBuffer, as: UTF8.self)
                    lineBuffer.removeAll(keepingCapacity: true)
                    previousByteWasCR = true
                    let shouldContinue = await onLine(line)
                    if !shouldContinue {
                        return
                    }
                } else {
                    previousByteWasCR = false
                    lineBuffer.append(byte)
                }
            }

            // 处理末尾无换行的剩余内容
            if !lineBuffer.isEmpty {
                _ = await onLine(String(decoding: lineBuffer, as: UTF8.self))
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HTTPClientError {
            throw error
        } catch {
            throw HTTPClientError.requestFailed(underlying: error)
        }
    }

    /// 发送不含请求体的 HTTP 请求（SSE 流式），按 SSE 行级别解析。
    ///
    /// - Parameters:
    ///   - request: 已配置好 URL、HTTP 方法、Header 的 URLRequest。
    ///   - onEvent: SSE 事件块回调，`event` 为事件类型（可能为 nil），`data` 为数据行数组（已去除 `data: ` 前缀），`id` 为事件 ID。
    ///   - Returns `false` 停止读取。
    /// - Throws: `HTTPClientError`。
    public func sendStreamingRequest(
        request: URLRequest,
        timeoutInterval: TimeInterval = 300,
        onEvent: @Sendable @escaping (_ event: String?, _ data: [String], _ id: String?) async -> Bool
    ) async throws {
        // SSE 协议保证事件按顺序到达，行级解析在单个 for-await 循环内顺序执行，
        // 因此 SSEAccumulator 的读写在同一个异步上下文中是安全的。
        final class SSEAccumulator: @unchecked Sendable {
            var event: String?
            var data: [String] = []
            var id: String?
        }
        let acc = SSEAccumulator()

        try await sendStreamingRequest(
            request: request,
            timeoutInterval: timeoutInterval
        ) { line in
            if line.isEmpty {
                // 空行 = 事件结束
                if !acc.data.isEmpty {
                    let shouldContinue = await onEvent(acc.event, acc.data, acc.id)
                    acc.event = nil
                    acc.data = []
                    acc.id = nil
                    return shouldContinue
                }
                acc.event = nil
                acc.data = []
                acc.id = nil
                return true
            }

            if line.hasPrefix("event:") {
                acc.event = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let dataLine = String(line.dropFirst(5))
                let cleanData = dataLine.hasPrefix(" ") ? String(dataLine.dropFirst()) : dataLine
                acc.data.append(cleanData)
            } else if line.hasPrefix("id:") {
                acc.id = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            // 注释行（以 : 开头）忽略
            return true
        }

        // 处理流结束时未以空行结尾的最后一个事件
        if !acc.data.isEmpty {
            _ = await onEvent(acc.event, acc.data, acc.id)
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

    private static func encodeEncodable<B: Encodable>(_ body: B) throws -> Data {
        do {
            return try JSONEncoder().encode(body)
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
            let hitCR = lastBytes.suffix(2).elementsEqual([0x0D, 0x0D])
            let hitCRLF = lastBytes.count >= 4 && lastBytes.suffix(4).elementsEqual([0x0D, 0x0A, 0x0D, 0x0A])

            if hitLF || hitCR || hitCRLF {
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
