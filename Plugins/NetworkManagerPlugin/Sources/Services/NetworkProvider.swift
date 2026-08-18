import Foundation
import KernelLumi
import Compression

/// 基于 URLSession 的 NetworkProviding 实现
///
/// 刻意 **不** 标 `@MainActor`:`session`(`URLSession`)和
/// `exchangeStore`(后台写入路径)都线程安全,无可变状态。这样 `stream` 的
/// SSE 字节循环和 `request`/`stream` 的交换记录写入都在后台执行,不占用主线程。
public final class NetworkProvider: NetworkProviding {
    public let session: URLSession
    public let exchangeStore: HTTPExchangeStore?

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
            let (bytes, urlResponse) = try await session.bytes(for: urlRequest)
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

                // Decompress the data
                let decompressed = Self.decompress(compressedData, encoding: contentEncoding ?? "")
                if let decompressed = decompressed {
                    // 解压后同样按 SSE 事件块切分（不能按 16KB 块，否则一个块内
                    // 多个 data 事件被拼成多行 JSON，上层 parseStreamChunk 解析失败）。
                    let shouldContinue = await emitSSEEvents(from: decompressed, onChunk: onChunk)
                    if !shouldContinue { return }
                } else {
                    // Fallback: send compressed data as-is
                    _ = await onChunk(compressedData)
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
                        if !shouldContinue { return }
                    }
                }
                // 流结束前未以空行结尾的剩余内容也要回调，避免丢最后一个事件。
                if !eventBuffer.isEmpty {
                    let shouldContinue = await onChunk(eventBuffer)
                    if !shouldContinue { return }
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
            let networkError = HTTPNetworkError(
                url: request.url,
                body: receivedBody,
                underlyingDescription: error.localizedDescription
            )
            exchangeStore?.finishRecord(recordID, response: response, body: receivedBody, error: networkError)
            throw networkError
        }
    }

    // MARK: - SSE Event Splitting

    /// 把一段完整的 SSE 正文按空行切分成多个事件块，逐块回调 `onChunk`。
    ///
    /// SSE 协议以空行（`\n\n` / `\r\r` / `\r\n\r\n`）分隔事件；上层
    /// `parseStreamChunk` 期望 `onChunk` 收到的是**单个**完整 `data:` 事件，
    /// 多个事件拼在同一次回调会让其 `JSONSerialization` 因多行 JSON 解析失败而丢弃。
    ///
    /// - Returns: `false` 表示调用方要求提前终止。
    private func emitSSEEvents(
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

    private static func decompress(_ data: Data, encoding: String) -> Data? {
        switch encoding {
        case "br":
            return decompressBrotli(data)
        case "gzip":
            return decompressGzip(data)
        case "deflate":
            return decompressDeflate(data)
        default:
            return nil
        }
    }

    private static func decompressBrotli(_ data: Data) -> Data? {
        // Use Apple's built-in brotli support via Compression framework
        let bufferSize = data.count * 10 // Estimate decompressed size
        var decompressedData = Data(count: bufferSize)

        let result: Int = data.withUnsafeBytes { (compressedPointer: UnsafeRawBufferPointer) -> Int in
            guard let compressedBaseAddress = compressedPointer.baseAddress else { return 0 }
            return decompressedData.withUnsafeMutableBytes { (decompressedPointer: UnsafeMutableRawBufferPointer) -> Int in
                guard let decompressedBaseAddress = decompressedPointer.baseAddress else { return 0 }
                return compression_decode_buffer(
                    decompressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                    bufferSize,
                    compressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_BROTLI
                )
            }
        }

        if result > 0 {
            return decompressedData.prefix(result)
        }
        return nil
    }

    private static func decompressGzip(_ data: Data) -> Data? {
        let bufferSize = data.count * 10
        var decompressedData = Data(count: bufferSize)

        let result: Int = data.withUnsafeBytes { (compressedPointer: UnsafeRawBufferPointer) -> Int in
            guard let compressedBaseAddress = compressedPointer.baseAddress else { return 0 }
            return decompressedData.withUnsafeMutableBytes { (decompressedPointer: UnsafeMutableRawBufferPointer) -> Int in
                guard let decompressedBaseAddress = decompressedPointer.baseAddress else { return 0 }
                return compression_decode_buffer(
                    decompressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                    bufferSize,
                    compressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        if result > 0 {
            return decompressedData.prefix(result)
        }
        return nil
    }

    private static func decompressDeflate(_ data: Data) -> Data? {
        let bufferSize = data.count * 10
        var decompressedData = Data(count: bufferSize)

        let result: Int = data.withUnsafeBytes { (compressedPointer: UnsafeRawBufferPointer) -> Int in
            guard let compressedBaseAddress = compressedPointer.baseAddress else { return 0 }
            return decompressedData.withUnsafeMutableBytes { (decompressedPointer: UnsafeMutableRawBufferPointer) -> Int in
                guard let decompressedBaseAddress = decompressedPointer.baseAddress else { return 0 }
                return compression_decode_buffer(
                    decompressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                    bufferSize,
                    compressedBaseAddress.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_LZFSE // Use LZFSE as fallback, may not work for all deflate streams
                )
            }
        }

        if result > 0 {
            return decompressedData.prefix(result)
        }
        return nil
    }

    private static func headers(from response: HTTPURLResponse) -> [String: String] {
        response.allHeaderFields.reduce(into: [String: String]()) { result, item in
            result[String(describing: item.key)] = String(describing: item.value)
        }
    }
}
