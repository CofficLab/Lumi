import Foundation
import KitLLM
import ProviderNetwork

/// 把 `NetworkProviding`（ProviderNetwork）桥接为 `LLMNetworkProviding`（KitLLM）。
///
/// 使 LLM 供应商的网络请求经过 kernel 的 `NetworkProviding`，
/// 从而获得 HTTP 交换记录等能力。
///
/// ## 错误归一化（重要）
///
/// 本适配器同时是**传输层错误 → KitLLM 错误**的边界，因此必须在此把
/// `HTTPNetworkError` 转换为 `VendorAPIError.httpStatus`。原因：
///
/// KitLLM 的两层重试都以 `VendorAPIError` / `LLMHTTPErrorProviding` 为准提取
/// HTTP 状态码：
/// - `VendorAPIService.retryDecision` — 传输层重试（`maxAttempts` 次）
/// - `AgentLoopFailure.from` — AgentLoop 整回合重试
///
/// 而 `HTTPNetworkError` 只有同名的 `statusCode` 存储属性，**未遵循**
/// `LLMHTTPErrorProviding`。Swift 的 `as?` 按协议遵循分派、不做鸭子类型匹配，
/// 因此状态码无法被提取，重试策略退化为 `decision(forNetworkError:)`，
/// 而该错误不在 `NSURLErrorDomain` 的可重试码列表中 → 判为不可重试。
///
/// 后果：MiniMax 等供应商返回 `HTTP 529`（服务集群负载较高）时完全不重试。
/// 归一化为 `VendorAPIError.httpStatus` 后，529 落入 `ProviderRetryPolicy`
/// 的 `500...599` 可重试区间，两层重试随即恢复。
public final class LLMNetworkProviderAdapter: LLMNetworkProviding {
    private let networkProvider: any NetworkProviding

    public init(_ networkProvider: any NetworkProviding) {
        self.networkProvider = networkProvider
    }

    // MARK: - LLMNetworkProviding

    public func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
        let httpMethod = HTTPMethod(rawValue: request.httpMethod ?? "POST") ?? .post
        var headers: [String: String] = [:]
        request.allHTTPHeaderFields?.forEach { headers[$0.key] = $0.value }
        if headers["Content-Type"] == nil {
            headers["Content-Type"] = "application/json"
        }
        let httpRequest = HTTPRequest(
            url: request.url ?? URL(string: "about:blank")!,
            method: httpMethod,
            headers: headers,
            body: body,
            timeout: Self.llmTimeout(request)
        )

        let httpResponse: HTTPResponse
        do {
            httpResponse = try await networkProvider.request(httpRequest)
        } catch {
            throw Self.normalized(error)
        }

        // 构造一个 HTTPURLResponse 用于 VendorAPIService 的 validateResponse
        let urlResponse = HTTPURLResponse(
            url: httpRequest.url,
            statusCode: httpResponse.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: httpResponse.headers
        )!

        return (httpResponse.body, urlResponse)
    }

    public func stream(
        request: URLRequest,
        body: Data,
        onEvent: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        let httpMethod = HTTPMethod(rawValue: request.httpMethod ?? "POST") ?? .post
        var headers: [String: String] = [:]
        request.allHTTPHeaderFields?.forEach { headers[$0.key] = $0.value }
        if headers["Content-Type"] == nil {
            headers["Content-Type"] = "application/json"
        }
        // SSE must remain byte-transparent. URLSession may advertise Brotli
        // in the response headers even after transparently decoding the body,
        // which makes the shared stream layer unable to distinguish compressed
        // bytes from plain SSE. Disable content encoding for LLM streams.
        headers["Accept-Encoding"] = "identity"

        let httpRequest = HTTPRequest(
            url: request.url ?? URL(string: "about:blank")!,
            method: httpMethod,
            headers: headers,
            body: body,
            timeout: Self.llmTimeout(request)
        )

        // 流式响应的状态码：非 2xx 必须在**转发任何 SSE 事件之前**抛出，
        // 否则 `VendorAPIService` 的 `EventReceipt` 会把 `hasReceived` 置真，
        // 其「首个事件前断线才安全重试」的保护将拒绝重放（重放会重复 token）。
        // 原实现写 `onResponse: { _ in }` 直接丢弃状态码，导致 529 等错误
        // 既拿不到状态码、也无法被正确识别。
        //
        // 用锁保护：`onResponse` 是 `@Sendable` 闭包，直接捕获并修改局部变量
        // 会触发 Swift 6 并发检查（`mutation of captured var in
        // concurrently-executing code`）。同时它与 `onChunk` 无顺序保证。
        let responseBox = ResponseMetadataBox()
        do {
            try await networkProvider.stream(
                httpRequest,
                onResponse: { metadata in
                    responseBox.store(metadata)
                },
                onChunk: { chunk in
                    await onEvent(chunk)
                }
            )
        } catch {
            throw Self.normalized(error)
        }

        if let metadata = responseBox.load(), !(200 ..< 300).contains(metadata.statusCode) {
            throw VendorAPIError.httpStatus(
                statusCode: metadata.statusCode,
                summary: "",
                retryAfterSeconds: HTTPRetryAfter.seconds(from: metadata.headers)
            )
        }
    }

    /// 跨并发边界传递流式响应元数据的线程安全盒子。
    ///
    /// `onResponse` 以 `@Sendable` 闭包跨越并发域，且与 `onChunk` 之间
    /// 没有 happens-before 关系，因此不能用普通局部变量承载。
    ///
    /// 需要连同响应头一起保存：状态码决定是否可重试，而 `Retry-After`
    /// 响应头决定重试前该等多久。
    private final class ResponseMetadataBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value: HTTPResponseMetadata?

        func store(_ metadata: HTTPResponseMetadata) {
            lock.lock(); defer { lock.unlock() }
            value = metadata
        }

        func load() -> HTTPResponseMetadata? {
            lock.lock(); defer { lock.unlock() }
            return value
        }
    }

    /// 把传输层错误归一化为 KitLLM 可识别的错误。
    ///
    /// - `HTTPNetworkError` 且带状态码 → `VendorAPIError.httpStatus(code, summary)`
    ///   使传输层重试与 AgentLoop 重试都能按状态码判定可重试性。
    /// - `HTTPNetworkError` 且仅有底层码（连接类失败）→ 转为
    ///   `NSURLErrorDomain` 错误，命中 `ProviderRetryPolicy.decision(forNetworkError:)`
    ///   的可重试白名单（超时、断网、连接丢失等）。
    /// - 其他错误（如 `CancellationError`）原样透出，由上层决定语义。
    ///
    /// 取消语义必须保留：用户主动停止不应触发任何重试。
    private static func normalized(_ error: Error) -> Error {
        if error is CancellationError { return error }

        guard let networkError = error as? HTTPNetworkError else { return error }

        if let statusCode = networkError.statusCode {
            return VendorAPIError.httpStatus(
                statusCode: statusCode,
                summary: Self.summary(from: networkError),
                // 服务端可能用 `Retry-After` 明确告知重试等待时间（429/529
                // 常见）。必须一路带到重试策略，否则等待时长只能由本地退避
                // 决定，会在服务端要求静默的窗口内继续加压。
                retryAfterSeconds: HTTPRetryAfter.seconds(from: networkError.headers)
            )
        }

        if let underlyingCode = networkError.underlyingCode {
            return NSError(
                domain: NSURLErrorDomain,
                code: underlyingCode,
                userInfo: [NSLocalizedDescriptionKey: networkError.underlyingDescription ?? networkError.localizedDescription]
            )
        }

        // 无状态码也无底层码：按传输失败处理，交给网络错误策略判定。
        return VendorAPIError.requestFailed(
            networkError.underlyingDescription ?? networkError.localizedDescription
        )
    }

    /// 从错误响应体提取可展示的摘要，供错误卡片显示。
    ///
    /// 与 `HTTPNetworkError.errorDescription` 的 JSON 信封解析保持一致
    /// （`error.message` → `message` → `detail`），但**不**回退到整个
    /// 正文：那会把供应商的长错误页塞进 UI。解析失败时返回空摘要。
    private static func summary(from error: HTTPNetworkError) -> String {
        guard let body = error.body, !body.isEmpty else { return "" }

        if let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            if let nested = object["error"] as? [String: Any],
               let message = nested["message"] as? String,
               !message.isEmpty {
                return message
            }
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
            if let detail = object["detail"] as? String, !detail.isEmpty {
                return detail
            }
        }

        guard let text = String(data: body, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return ""
        }
        // 上游 HTTPNetworkError 截断到 2000 字符，这里收敛得更紧。
        return String(text.prefix(200))
    }

    /// LLM 请求的空闲超时。
    ///
    /// `URLRequest.timeoutInterval` 默认 60s，且一旦显式写入会覆盖 session 级
    /// 配置。流式 LLM（思考模式）在首个 SSE 事件前可能长时间无字节，60s 会把
    /// 尚未开始的流掐断，导致 `VendorAPIError.incompleteStream`
    /// （「流式响应在收到结束信号前中断」）。这里保证 LLM 请求至少 300s，
    /// 若调用方显式配置了更大的超时则尊重调用方。
    private static func llmTimeout(_ request: URLRequest) -> TimeInterval {
        max(request.timeoutInterval, 300)
    }
}
