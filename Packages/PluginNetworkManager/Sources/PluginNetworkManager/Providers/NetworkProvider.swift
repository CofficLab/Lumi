import Foundation
import ProviderNetwork
import Compression

/// 基于 URLSession 的 NetworkProviding 实现
///
/// 刻意 **不** 标 `@MainActor`:`session`(`URLSession`)和
/// `exchangeStore`(后台写入路径)都线程安全,无可变状态。这样 `stream` 的
/// SSE 字节循环和 `request`/`stream` 的交换记录写入都在后台执行,不占用主线程。
public final class NetworkProvider: NetworkProviding {
    public let session: URLSession
    public let exchangeStore: HTTPExchangeStore?

    /// 默认使用长空闲超时的 session。
    ///
    /// 流式 LLM（如 MiniMax-M3 思考模式，reasoning=high）在首个 SSE 事件前
    /// 可能长时间无字节；`URLSession.shared` 的 60s 空闲超时会把尚未开始的
    /// 流掐断，客户端随后报 `VendorAPIError.incompleteStream`
    /// （「流式响应在收到结束信号前中断」）。这里把空闲超时放大到 300s。
    public init(session: URLSession? = nil, exchangeStore: HTTPExchangeStore? = nil) {
        self.session = session ?? NetworkProvider.makeLongTimeoutSession()
        self.exchangeStore = exchangeStore
    }

    private static func makeLongTimeoutSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 600
        return URLSession(configuration: configuration)
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
        let recordID = exchangeStore?.beginRecord(request: urlRequest, startedAt: startedAt)
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            exchangeStore?.finishRecord(recordID, error: error)
            throw HTTPNetworkError(
                url: request.url,
                underlyingDescription: error.localizedDescription
            )
        } catch {
            exchangeStore?.finishRecord(recordID, error: error)
            throw HTTPNetworkError(
                url: request.url,
                underlyingDescription: error.localizedDescription
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            let error = HTTPNetworkError(url: request.url, body: data, underlyingDescription: "Invalid response")
            exchangeStore?.finishRecord(recordID, response: response, body: data, error: error)
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
            exchangeStore?.finishRecord(recordID, response: httpResponse, body: data, error: detailedError)
            throw detailedError
        }

        exchangeStore?.finishRecord(recordID, response: httpResponse, body: data)

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
        let recordID = exchangeStore?.beginRecord(request: urlRequest, startedAt: startedAt)
        var receivedBody = Data()
        var response: URLResponse?

        do {
            // 应用层兜底超时：`URLSession` 的 `timeoutIntervalForRequest` 对
            // "连接已建立但服务端迟迟不返回响应头"的挂起连接不可靠（实测挂起
            // 20+ 分钟不触发，交换记录停留在 beginRecord 未收口，UI 长时间
            // "正在思考"）。用竞速任务保证等待响应头最多
            // `responseHeaderTimeout` 秒即失败并收口，上层按可重试错误快速重试。
            let (bytes, urlResponse) = try await Self.withResponseHeaderTimeout(
                session: session,
                urlRequest: urlRequest,
                url: request.url,
                timeout: 60
            )
            response = urlResponse
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                let error = HTTPNetworkError(url: request.url, underlyingDescription: "Invalid response")
                exchangeStore?.finishRecord(recordID, response: urlResponse, body: receivedBody, error: error)
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

            // Check for Content-Encoding
            let contentEncoding = headers["Content-Encoding"]?.lowercased()
            let isCompressed = contentEncoding == "br" || contentEncoding == "gzip" || contentEncoding == "deflate"

            if isCompressed {
                // For compressed streams, we need to buffer and decompress
                var compressedData = Data()
                for try await byte in bytes {
                    try Task.checkCancellation()
                    compressedData.append(byte)
                }
                receivedBody = compressedData

                // URLSession can transparently decode a body while preserving
                // Content-Encoding. Prefer already-readable SSE before trying
                // to decode it a second time.
                let decompressed = Self.looksLikeSSE(compressedData)
                    ? compressedData
                    : Self.decompress(compressedData, encoding: contentEncoding ?? "")
                if let decompressed = decompressed {
                    // 解压后同样按 SSE 事件块切分（不能按 16KB 块，否则一个块内
                    // 多个 data 事件被拼成多行 JSON，上层 parseStreamChunk 解析失败）。
                    let shouldContinue = await emitSSEEvents(from: decompressed, onChunk: onChunk)
                    if !shouldContinue {
                        // 提前停止读取仍然是一次已结束的 HTTP exchange，不能跳过收口。
                        exchangeStore?.finishRecord(recordID, response: response, body: receivedBody)
                        return
                    }
                } else {
                    // Fallback：解压失败时把已收到的字节按 SSE 事件块切分，逐块回调。
                    //
                    // 关键场景：URLSession 对 Brotli 流会自动解压，但响应头仍保留
                    // `Content-Encoding: br`，导致这里 `isCompressed == true`，而
                    // `compressedData` 实际已是明文 SSE。若像历史 bug 那样把整段
                    // 一次性 `onChunk`，上层 `parseStreamChunk` 会拿到多行拼接的
                    // JSON 而解析失败、全部丢弃，最终误报
                    // `VendorAPIError.incompleteStream`（「流式响应在收到结束信号前
                    // 中断」）。按空行切分后每个事件都是单行 `data:` JSON，可正常解析。
                    let shouldContinue = await emitSSEEvents(from: compressedData, onChunk: onChunk)
                    if !shouldContinue {
                        exchangeStore?.finishRecord(recordID, response: response, body: receivedBody)
                        return
                    }
                }
            } else {
                // Uncompressed stream - 边接收边按 SSE 空行切分完整事件块，保证
                // 实时逐事件回调，同时避免把多个 data 事件拼成多行 JSON。
                //
                // 历史 bug：这里按每 16KB 一块回调。一个 16KB 网络块通常包含**多个**
                // SSE `data: {...}` 事件，它们被拼成多行拼进同一份 JSON，导致上层
                // （OpenAICompatibleProviderAdapter.parseStreamChunk → extractSSEData
                // → JSONSerialization）对多行 JSON 解析失败并丢弃 —— 流式正文全部丢失，
                // 最终 assistant 消息落库为空，尽管 wire 上能看到完整内容。
                var eventBuffer = Data()
                var lastBytes: [UInt8] = []
                for try await byte in bytes {
                    try Task.checkCancellation()
                    receivedBody.append(byte)
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
                        let eventData = eventBuffer.dropLast(delimiterLength)
                        eventBuffer.removeAll(keepingCapacity: true)
                        lastBytes.removeAll(keepingCapacity: true)

                        guard !eventData.isEmpty else { continue }
                        let shouldContinue = await onChunk(Data(eventData))
                        if !shouldContinue {
                            // 提前停止读取仍然是一次已结束的 HTTP exchange，不能跳过收口。
                            exchangeStore?.finishRecord(recordID, response: response, body: receivedBody)
                            return
                        }
                    }
                }
                // 流结束前未以空行结尾的剩余内容也要回调，避免丢最后一个事件。
                if !eventBuffer.isEmpty {
                    let shouldContinue = await onChunk(eventBuffer)
                    if !shouldContinue {
                        exchangeStore?.finishRecord(recordID, response: response, body: receivedBody)
                        return
                    }
                }
            }

            if !(200..<300).contains(httpResponse.statusCode) {
                throw HTTPNetworkError(
                    url: request.url,
                    statusCode: httpResponse.statusCode,
                    headers: headers,
                    body: receivedBody
                )
            }
            exchangeStore?.finishRecord(recordID, response: httpResponse, body: receivedBody)
        } catch is CancellationError {
            exchangeStore?.finishRecord(recordID, response: response, body: receivedBody, error: CancellationError())
            throw CancellationError()
        } catch let error as HTTPNetworkError {
            exchangeStore?.finishRecord(recordID, response: response, body: receivedBody, error: error)
            throw error
        } catch {
            let nsError = error as NSError
            let networkError = HTTPNetworkError(
                url: request.url,
                body: receivedBody,
                underlyingDescription: error.localizedDescription,
                underlyingCode: nsError.domain == NSURLErrorDomain ? nsError.code : nil
            )
            exchangeStore?.finishRecord(recordID, response: response, body: receivedBody, error: networkError)
            throw networkError
        }
    }

    // MARK: - SSE Event Splitting

    /// 在等待响应头阶段应用层兜底超时。
    ///
    /// `URLSession.timeoutIntervalForRequest` 只对"请求发出→收到响应头"阶段
    /// 严格生效，但实测中连接已建立、服务端不返回响应头时可能长期不触发
    /// （交换记录停在 `beginRecord` 未收口）。用竞速任务保证最迟
    /// `timeout` 秒内失败：超时任务先完成则抛可重试的 `HTTPNetworkError`，
    /// 并取消底层 `bytes` 任务释放挂起连接；正常则返回 `(bytes, response)`。
    private static func withResponseHeaderTimeout(
        session: URLSession,
        urlRequest: URLRequest,
        url: URL,
        timeout: TimeInterval
    ) async throws -> (URLSession.AsyncBytes, URLResponse) {
        try await withThrowingTaskGroup(of: (URLSession.AsyncBytes, URLResponse).self) { group in
            group.addTask {
                try await session.bytes(for: urlRequest)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw HTTPNetworkError(
                    url: url,
                    underlyingDescription: "等待响应头超时（\(Int(timeout))s，连接无响应）"
                )
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw HTTPNetworkError(url: url, underlyingDescription: "连接无响应")
            }
            return result
        }
    }

    /// 把一段完整的 SSE 正文按空行切分成多个事件块，逐块回调 `onChunk`。
    ///
    /// SSE 协议以空行（`\n\n` / `\r\r` / `\r\n\r\n`）分隔事件；上层
    /// `parseStreamChunk` 期望 `onChunk` 收到的是**单个**完整 `data:` 事件，
    /// 多个事件拼在同一次回调会让其 `JSONSerialization` 因多行 JSON 解析失败而丢弃。
    ///
    /// - Returns: `false` 表示调用方要求提前终止。
    func emitSSEEvents(
        from data: Data,
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async -> Bool {
        var eventBuffer = Data()
        var lastBytes: [UInt8] = []

        for byte in data {
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
                let shouldContinue = await onChunk(Data(eventData))
                if !shouldContinue { return false }
            }
        }

        // 流结束前未以空行结尾的剩余内容也要回调，避免丢最后一个事件。
        if !eventBuffer.isEmpty {
            let shouldContinue = await onChunk(eventBuffer)
            if !shouldContinue { return false }
        }
        return true
    }

    // MARK: - Decompression

    private static func looksLikeSSE(_ data: Data) -> Bool {
        guard let prefix = String(data: data.prefix(4 * 1024), encoding: .utf8) else { return false }
        return prefix
            .split(whereSeparator: \.isNewline)
            .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("data:") }
    }

    static func decompress(_ data: Data, encoding: String) -> Data? {
        switch encoding {
        case "br":
            return decompress(data, algorithm: COMPRESSION_BROTLI)
        case "gzip":
            return decompress(data, algorithm: COMPRESSION_ZLIB)
        case "deflate":
            return decompress(data, algorithm: COMPRESSION_ZLIB)
        default:
            return nil
        }
    }

    private static func decompress(_ data: Data, algorithm: compression_algorithm) -> Data? {
        guard !data.isEmpty else { return Data() }

        // Compression ratio is not bounded by a small fixed multiplier for
        // repetitive SSE JSON. Grow the destination until decoding succeeds;
        // never pass a partially decoded buffer to the SSE parser.
        var capacity = max(data.count * 2, 4 * 1024)
        let maximumCapacity = 64 * 1024 * 1024

        while capacity <= maximumCapacity {
            var decompressedData = Data(count: capacity)
            let result: Int = data.withUnsafeBytes { compressedPointer in
                guard let compressedBaseAddress = compressedPointer.baseAddress else { return 0 }
                return decompressedData.withUnsafeMutableBytes { decompressedPointer in
                    guard let decompressedBaseAddress = decompressedPointer.baseAddress else { return 0 }
                    return compression_decode_buffer(
                        decompressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                        capacity,
                        compressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                        data.count,
                        nil,
                        algorithm
                    )
                }
            }

            // A result equal to the capacity may indicate that the output
            // buffer was filled exactly or was too small, so grow once more.
            if result > 0, result < capacity {
                return decompressedData.prefix(result)
            }
            capacity *= 2
        }

        return nil
    }

    private static func headers(from response: HTTPURLResponse) -> [String: String] {
        response.allHeaderFields.reduce(into: [String: String]()) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
    }
}
