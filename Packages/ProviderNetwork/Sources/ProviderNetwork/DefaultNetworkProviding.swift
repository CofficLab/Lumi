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

        // 按 SSE 空行切分完整事件块再回调，而非逐字节回调。
        //
        // 历史 bug：这里曾用 `while let byte { await onChunk(Data([byte])) }` 把
        // 响应正文**逐字节**喂给上层，而上层（如 OpenAICompatibleProviderAdapter
        // .parseStreamChunk）依赖完整的 `data: {...}` 行，单字节几乎必然解析失败
        // → 流式正文全部丢失，最终 assistant 消息落库为空。尽管 wire 上（HTTP
        // 交换记录 body）能看到完整内容。
        //
        // 现改为与 HttpKit.readServerSentEvents 一致的实现：累积字节，按空行
        // （`\n\n` / `\r\r` / `\r\n\r\n`）切出完整事件块，再把整块 `Data` 回调给
        // 上层解析。TCP 分片（一个事件被多个网络包拆分）也能正确拼接。
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
                let shouldContinue = await onChunk(Data(eventData))
                if !shouldContinue { return }
            }
        }

        // 流结束前未以空行结尾的剩余内容也要回调，避免丢最后一个事件。
        if !eventBuffer.isEmpty {
            _ = await onChunk(eventBuffer)
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
