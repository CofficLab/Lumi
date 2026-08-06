import Foundation
import LumiKernel

// MARK: - 事件

/// DeepSeek 走 Anthropic 协议时的单个 SSE 事件解码结果。
///
/// 与 `DeepSeekEvent`（OpenAI 协议）平行存在，二者字段模型不互通。
/// 这里承载的是 Anthropic Messages API 的事件：
/// `message_start` / `content_block_start` / `content_block_delta` /
/// `content_block_stop` / `message_delta` / `message_stop` / 顶层 `error`。
struct AnthropicEvent: Sendable {
    /// 来自 `content_block_delta(type=text)` 的文本增量。
    let textDelta: String?
    /// 来自 `content_block_delta(type=thinking)` 的思考增量（如果 DeepSeek 透传）。
    let thinkingDelta: String?
    /// 来自 `content_block_delta(type=signature_delta)` 的思考签名。
    ///
    /// DeepSeek 为每个 thinking block 返回 `signature`(实测 2026-08-06)。
    /// 若回传 assistant 消息时不带真实 signature(用空串),thinking block 与
    /// DeepSeek 落盘的缓存前缀单元不一致 → 从第一条 assistant 起前缀失配、缓存全 miss。
    let thinkingSignature: String?
    /// 来自 `content_block_delta(type=input_json_delta)` 累积后的工具入参。
    /// Anthropic 把工具入参以增量 JSON 字符串形式发出；这里保留累积视图。
    let toolInputJSONDelta: String?
    /// 来自 `content_block_start` 的工具名（首个 delta 时携带）。
    let toolName: String?
    /// 来自 `content_block_start` 的工具 id（首个 delta 时携带）。
    let toolID: String?
    /// 来自 `message_delta` 的 `stop_reason`（`end_turn` / `tool_use` / `max_tokens` / `stop_sequence`）。
    let stopReason: String?
    /// 来自 `message_delta` 的 `stop_sequence`（命中自定义停止符时回传）。
    let stopSequence: String?
    /// 来自 `message_start.message.usage` 与 `message_delta.usage` 的合并视图。
    let usage: DeepSeekAnthropicUsage?
    /// 流终止：来自 `message_stop`，或解析 `[DONE]` 哨兵。
    let done: Bool
    /// 协议层错误（来自 SSE `event: error` 或顶层 JSON `error` 字段）。
    let error: String?

    /// 统一构造入口：`thinkingSignature` 等字段带默认值，避免每个构造点重复传参。
    init(
        textDelta: String? = nil,
        thinkingDelta: String? = nil,
        thinkingSignature: String? = nil,
        toolInputJSONDelta: String? = nil,
        toolName: String? = nil,
        toolID: String? = nil,
        stopReason: String? = nil,
        stopSequence: String? = nil,
        usage: DeepSeekAnthropicUsage? = nil,
        done: Bool = false,
        error: String? = nil
    ) {
        self.textDelta = textDelta
        self.thinkingDelta = thinkingDelta
        self.thinkingSignature = thinkingSignature
        self.toolInputJSONDelta = toolInputJSONDelta
        self.toolName = toolName
        self.toolID = toolID
        self.stopReason = stopReason
        self.stopSequence = stopSequence
        self.usage = usage
        self.done = done
        self.error = error
    }
}

/// Anthropic 协议 usage 字段的合并视图。
///
/// `input_tokens` / `output_tokens` 来自 `message_start.message.usage` 与
/// `message_delta.usage` 的并集；`cache_read_input_tokens` /
/// `cache_creation_input_tokens` 是 Anthropic 原生缓存字段，DeepSeek 不一定透传，
/// 暂以可选形式承载。
struct DeepSeekAnthropicUsage: Sendable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?
}

// MARK: - Service

/// DeepSeek（Anthropic-compatible flavor）的 transport / 请求编码 / SSE 解析。
///
/// 平行于 `DeepSeekOpenAIService`：
/// - 端点：`{baseURL}/v1/messages`，baseURL 默认 `https://api.deepseek.com/anthropic`
/// - 鉴权：`x-api-key` + `anthropic-version: 2023-06-01`
/// - 请求体：Anthropic Messages API 风格（`model` / `max_tokens` / `system` /
///   `messages` / `stream` / `tools` / `thinking` 等）
/// - 响应：SSE，事件类型见 `DeepSeekAnthropicEvent` 的文档
///
/// 同样不依赖 LLMKit，独立于 OpenAI 协议实现。
final class DeepSeekAnthropicService: @unchecked Sendable {
    let baseURL: String
    private let network: (any NetworkProviding)?

    init(
        baseURL: String = "https://api.deepseek.com/anthropic",
        network: (any NetworkProviding)? = nil
    ) {
        self.baseURL = baseURL
        self.network = network
    }

    /// 构造一个 Anthropic Messages API 请求所需的 `URLRequest`。
    ///
    /// 调用方负责提供 `apiKey`（来自 `LumiLLMProvider.lumiResolveAPIKey()`），
    /// 以及编码好的 `body`（推荐由 `DeepSeekAnthropicRequestBuilder` 生成）。
    func makeRequest(apiKey: String, body: Data) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw DeepSeekAnthropicTransportError.invalidURL(baseURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = body
        return request
    }

    /// 发起流式请求。
    ///
    /// `onChunk` 在每个 SSE 事件解析后被调用；返回 `false` 即可中止消费。
    /// 该方法只完成"网络 + SSE 解析"两件事，不负责组装 `DeepSeekChatMessage`
    /// —— 把组装留给上层。
    func send(
        apiKey: String,
        body: Data,
        onChunk: @Sendable @escaping (AnthropicEvent) async -> Bool
    ) async throws {
        guard let network else {
            throw DeepSeekAnthropicTransportError.networkUnavailable
        }
        let request = try makeRequest(apiKey: apiKey, body: body)
        let networkRequest = HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody,
            timeout: max(request.timeoutInterval, 300)
        )
        // 网络层按 ~16KB 回调原始字节,不保证 SSE 帧完整;必须跨 chunk 累积成
        // 完整帧再解析,否则大 content_block_delta 会丢失,thinking/text 不完整,
        // 导致存储的消息与模型输出不一致、历史回传前缀失配、缓存命中率崩盘。
        let accumulator = SSESequenceAccumulator()
        try await network.stream(
            networkRequest,
            onResponse: { _ in },
            onChunk: { data in
                for frame in accumulator.appendAndDrain(data) {
                    for event in DeepSeekAnthropicEventParser.parse(frame) {
                        if !(await onChunk(event)) { return false }
                    }
                }
                return true
            }
        )
        if let remaining = accumulator.drainRemaining() {
            for event in DeepSeekAnthropicEventParser.parse(remaining) {
                _ = await onChunk(event)
            }
        }
    }

    /// 非流式请求（用于 ping / availability check）。
    func sendOnce(apiKey: String, body: Data) async throws -> Data {
        guard let network else {
            throw DeepSeekAnthropicTransportError.networkUnavailable
        }
        let request = try makeRequest(apiKey: apiKey, body: body)
        let response = try await network.request(HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody,
            timeout: request.timeoutInterval
        ))
        guard response.isSuccess else {
            throw DeepSeekAnthropicTransportError.httpStatus(
                response.statusCode,
                response.bodyString ?? ""
            )
        }
        return response.body
    }
}

// MARK: - Transport Error

/// DeepSeek Anthropic 协议层的传输错误。
///
/// 平行于 `DeepSeekTransportError`，独立命名以便后续按协议 flavor 区分。
enum DeepSeekAnthropicTransportError: LocalizedError {
    case networkUnavailable
    case invalidURL(String)
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network is unavailable"
        case let .invalidURL(url):
            return "Invalid DeepSeek Anthropic URL: \(url)"
        case let .httpStatus(code, body):
            return "DeepSeek Anthropic HTTP \(code): \(body)"
        }
    }
}

// MARK: - SSE Parser

/// Anthropic Messages API 的 SSE 解析器（针对 DeepSeek 端点）。
///
/// Anthropic 的 SSE 是 `event: <type>\ndata: <json>\n\n` 双行结构（事件类型在
/// `event:` 行，数据在 `data:` 行）。`message_stop` 的 `data` 为空，但仍需触发
/// `done` 事件以通知上层收尾。
enum DeepSeekAnthropicEventParser {
    static func parse(_ data: Data) -> [AnthropicEvent] {
        let text = String(decoding: data, as: UTF8.self)
        var events: [AnthropicEvent] = []
        // 按空行分段（SSE 帧分隔符）
        let frames = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for frame in frames {
            var eventType: String?
            var payload: String?

            for rawLine in frame.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = String(rawLine)
                if line.hasPrefix("event:") {
                    eventType = String(line.dropFirst("event:".count))
                        .trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    let chunk = String(line.dropFirst("data:".count))
                        .trimmingCharacters(in: .whitespaces)
                    payload = chunk
                }
            }

            if let eventType, eventType == "ping" {
                // ping 帧无 data，跳过；调用方不需要感知心跳
                continue
            }

            // 顶层 error：Anthropic 协议会在错误时发送 `event: error` + JSON body
            if eventType == "error", let json = decode(payload) {
                let message = (json["error"] as? [String: Any])?["message"] as? String
                    ?? json["message"] as? String
                events.append(AnthropicEvent(
                    textDelta: nil,
                    thinkingDelta: nil,
                    toolInputJSONDelta: nil,
                    toolName: nil,
                    toolID: nil,
                    stopReason: nil,
                    stopSequence: nil,
                    usage: nil,
                    done: false,
                    error: message ?? "DeepSeek Anthropic error"
                ))
                continue
            }

            guard let payload, let json = decode(payload) else { continue }

            switch eventType {
            case "message_start":
                let usage = parseUsage(json["message"] as? [String: Any])
                events.append(AnthropicEvent(
                    textDelta: nil, thinkingDelta: nil,
                    toolInputJSONDelta: nil, toolName: nil, toolID: nil,
                    stopReason: nil, stopSequence: nil,
                    usage: usage,
                    done: false, error: nil
                ))
            case "content_block_start":
                let block = json["content_block"] as? [String: Any]
                let type = block?["type"] as? String
                if type == "tool_use" {
                    events.append(AnthropicEvent(
                        textDelta: nil, thinkingDelta: nil,
                        toolInputJSONDelta: nil,
                        toolName: block?["name"] as? String,
                        toolID: block?["id"] as? String,
                        stopReason: nil, stopSequence: nil,
                        usage: nil,
                        done: false, error: nil
                    ))
                }
            case "content_block_delta":
                let delta = json["delta"] as? [String: Any]
                let type = delta?["type"] as? String
                switch type {
                case "text_delta":
                    events.append(AnthropicEvent(
                        textDelta: delta?["text"] as? String,
                        thinkingDelta: nil,
                        toolInputJSONDelta: nil,
                        toolName: nil, toolID: nil,
                        stopReason: nil, stopSequence: nil,
                        usage: nil,
                        done: false, error: nil
                    ))
                case "thinking_delta":
                    events.append(AnthropicEvent(
                        textDelta: nil,
                        thinkingDelta: delta?["thinking"] as? String,
                        toolInputJSONDelta: nil,
                        toolName: nil, toolID: nil,
                        stopReason: nil, stopSequence: nil,
                        usage: nil,
                        done: false, error: nil
                    ))
                case "signature_delta":
                    // DeepSeek 为每个 thinking block 回传签名(实测 2026-08-06)。
                    // 必须保存并在回传 assistant 消息时带上,否则 thinking block 与
                    // 缓存落盘单元不一致,从该消息起前缀失配、缓存全 miss。
                    events.append(AnthropicEvent(
                        textDelta: nil, thinkingDelta: nil,
                        thinkingSignature: delta?["signature"] as? String,
                        toolInputJSONDelta: nil,
                        toolName: nil, toolID: nil,
                        stopReason: nil, stopSequence: nil,
                        usage: nil,
                        done: false, error: nil
                    ))
                case "input_json_delta":
                    events.append(AnthropicEvent(
                        textDelta: nil, thinkingDelta: nil,
                        toolInputJSONDelta: delta?["partial_json"] as? String,
                        toolName: nil, toolID: nil,
                        stopReason: nil, stopSequence: nil,
                        usage: nil,
                        done: false, error: nil
                    ))
                default:
                    break
                }
            case "content_block_stop":
                // 当前未携带工具完成信号；tool 列表由 content_block_start/delta
                // 共同构造，stop 在此无需额外字段。
                break
            case "message_delta":
                let delta = json["delta"] as? [String: Any]
                let usage = parseUsage(json)
                events.append(AnthropicEvent(
                    textDelta: nil, thinkingDelta: nil,
                    toolInputJSONDelta: nil,
                    toolName: nil, toolID: nil,
                    stopReason: delta?["stop_reason"] as? String,
                    stopSequence: delta?["stop_sequence"] as? String,
                    usage: usage,
                    done: false, error: nil
                ))
            case "message_stop":
                events.append(AnthropicEvent(
                    textDelta: nil, thinkingDelta: nil,
                    toolInputJSONDelta: nil,
                    toolName: nil, toolID: nil,
                    stopReason: nil, stopSequence: nil,
                    usage: nil,
                    done: true, error: nil
                ))
            default:
                break
            }
        }
        return events
    }

    private static func decode(_ payload: String?) -> [String: Any]? {
        guard let payload, let data = payload.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func parseUsage(_ json: [String: Any]?) -> DeepSeekAnthropicUsage? {
        guard let json else { return nil }
        guard let usage = json["usage"] as? [String: Any] else { return nil }
        return DeepSeekAnthropicUsage(
            inputTokens: usage["input_tokens"] as? Int,
            outputTokens: usage["output_tokens"] as? Int,
            cacheReadInputTokens: usage["cache_read_input_tokens"] as? Int,
            cacheCreationInputTokens: usage["cache_creation_input_tokens"] as? Int
        )
    }
}
