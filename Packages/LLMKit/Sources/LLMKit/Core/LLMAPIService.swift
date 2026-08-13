import Foundation
import HttpKit
import KernelLumi

/// LLM API 服务
///
/// 保留 LLM 模块内的调用入口，底层 HTTP 传输能力由 `HttpKit` 提供。
/// 此类不包含重试逻辑，重试策略由上层统一管理。
public class LLMAPIService: @unchecked Sendable {
    private let client: HTTPClient?
    private let network: (any NetworkProviding)?

    public init(client: HTTPClient = HTTPClient()) {
        self.client = client
        self.network = nil
    }

    /// Creates an LLM transport backed by Kernel. The HTTP implementation and
    /// logging then come from NetworkManagerPlugin.
    public init(network: any NetworkProviding) {
        self.client = nil
        self.network = network
    }

    @MainActor
    public init(kernel: KernelLumi) {
        if let network = kernel.network {
            self.client = nil
            self.network = network
        } else {
            self.client = HTTPClient()
            self.network = nil
        }
    }

    /// 发送聊天完成请求（单次，不含重试）。
    public func sendChatRequest(
        request: URLRequest,
        body: [String: Any]
    ) async throws -> Data {
        let bodyData: Data
        do {
            // .sortedKeys 保证 JSON 字节序列稳定:Swift 的 [String: Any] 字典无序,
            // 若不加此选项,每次请求序列化出的 key 顺序不同;支持前缀缓存的端点
            // (DeepSeek/Anthropic/Kimi 等)按「从 token 0 起的前缀 token 序列」匹配,
            // key 顺序一变整段缓存失配(命中率从 90%+ 崩到 2-5%,已实测复现)。
            bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        } catch {
            throw HTTPClientError.jsonSerializationFailed(underlying: error)
        }

        if let network {
            do {
                return try await network.request(Self.httpRequest(from: request, body: bodyData)).body
            } catch let error as HTTPNetworkError {
                throw Self.httpClientError(from: error)
            }
        }
        return try await client!.sendJSONRequest(request: request, body: body)
    }

    /// 发送流式聊天请求，使用 SSE 空行分隔事件。
    public func sendStreamingRequest(
        request: URLRequest,
        body: [String: Any],
        onRequestStart: @Sendable @escaping (HTTPRequestMetadata) async -> Void = { _ in },
        onResponseReceived: @Sendable @escaping (HTTPURLResponse) async -> Void = { _ in },
        onChunk: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        let bodyData: Data
        do {
            // .sortedKeys 保证 JSON 字节序列稳定:Swift 的 [String: Any] 字典无序,
            // 若不加此选项,每次请求序列化出的 key 顺序不同;支持前缀缓存的端点
            // (DeepSeek/Anthropic/Kimi 等)按「从 token 0 起的前缀 token 序列」匹配,
            // key 顺序一变整段缓存失配(命中率从 90%+ 崩到 2-5%,已实测复现)。
            bodyData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        } catch {
            throw HTTPClientError.jsonSerializationFailed(underlying: error)
        }

        if let network {
            var streamRequest = request
            streamRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            streamRequest.timeoutInterval = max(streamRequest.timeoutInterval, 300)
            let metadata = HTTPRequestMetadata(
                requestId: UUID(),
                method: streamRequest.httpMethod ?? "POST",
                url: streamRequest.url?.absoluteString ?? "unknown",
                requestHeaders: streamRequest.allHTTPHeaderFields ?? [:],
                requestBodySizeBytes: bodyData.count,
                requestBodyPreview: String(data: bodyData, encoding: .utf8),
                sentAt: Date()
            )
            await onRequestStart(metadata)

            let decoder = SSEEventDecoder(onEvent: onChunk)
            do {
                try await network.stream(
                    Self.httpRequest(from: streamRequest, body: bodyData),
                    onResponse: { response in
                        guard let httpResponse = HTTPURLResponse(
                            url: response.url,
                            statusCode: response.statusCode,
                            httpVersion: "HTTP/1.1",
                            headerFields: response.headers
                        ) else { return }
                        await onResponseReceived(httpResponse)
                    },
                    onChunk: { chunk in
                        await decoder.append(chunk)
                    }
                )
            } catch let error as HTTPNetworkError {
                throw Self.httpClientError(from: error)
            }
            await decoder.finish()
            return
        }

        try await client!.sendStreamingJSONRequest(
            request: request,
            body: body,
            onRequestStart: onRequestStart,
            onResponseReceived: onResponseReceived,
            onEvent: onChunk
        )
    }

    private static func httpRequest(from request: URLRequest, body: Data) -> HTTPRequest {
        HTTPRequest(
            url: request.url ?? URL(string: "about:blank")!,
            method: HTTPMethod(rawValue: request.httpMethod ?? "GET") ?? .get,
            headers: request.allHTTPHeaderFields ?? [:],
            body: body,
            timeout: request.timeoutInterval
        )
    }

    private static func httpClientError(from error: HTTPNetworkError) -> HTTPClientError {
        if let statusCode = error.statusCode {
            return .httpError(
                statusCode: statusCode,
                message: String(data: error.body ?? Data(), encoding: .utf8) ?? error.localizedDescription
            )
        }
        return .requestFailed(underlying: error)
    }
}

private final class SSEEventDecoder: @unchecked Sendable {
    private var buffer = Data()
    private let onEvent: @Sendable (Data) async -> Bool
    private var stopped = false

    init(onEvent: @escaping @Sendable (Data) async -> Bool) {
        self.onEvent = onEvent
    }

    func append(_ data: Data) async -> Bool {
        guard !stopped else { return false }
        buffer.append(data)
        while let delimiter = Self.delimiter(in: buffer) {
            let event = buffer.prefix(delimiter.range)
            buffer.removeFirst(delimiter.range + delimiter.length)
            guard !event.isEmpty else { continue }
            if !(await onEvent(Data(event))) {
                stopped = true
                return false
            }
        }
        return !stopped
    }

    func finish() async {
        guard !stopped, !buffer.isEmpty else { return }
        _ = await onEvent(buffer)
        buffer.removeAll(keepingCapacity: false)
    }

    private static func delimiter(in data: Data) -> (range: Int, length: Int)? {
        let bytes = [UInt8](data)
        for index in bytes.indices {
            if index + 3 < bytes.count,
               bytes[index] == 0x0D, bytes[index + 1] == 0x0A,
               bytes[index + 2] == 0x0D, bytes[index + 3] == 0x0A {
                return (index, 4)
            }
            if index + 1 < bytes.count,
               (bytes[index] == 0x0A && bytes[index + 1] == 0x0A)
                || (bytes[index] == 0x0D && bytes[index + 1] == 0x0D) {
                return (index, 2)
            }
        }
        return nil
    }
}
