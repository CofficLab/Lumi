import Foundation
import LumiKernel

// MARK: - Anthropic 事件

struct AnthropicKimiCodeEvent: Sendable {
    let textDelta: String?
    let thinkingDelta: String?
    let thinkingSignature: String?
    let toolInputJSONDelta: String?
    let toolName: String?
    let toolID: String?
    let stopReason: String?
    let stopSequence: String?
    let usage: KimiCodeAnthropicUsage?
    let done: Bool
    let error: String?

    init(
        textDelta: String? = nil,
        thinkingDelta: String? = nil,
        thinkingSignature: String? = nil,
        toolInputJSONDelta: String? = nil,
        toolName: String? = nil,
        toolID: String? = nil,
        stopReason: String? = nil,
        stopSequence: String? = nil,
        usage: KimiCodeAnthropicUsage? = nil,
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

struct KimiCodeAnthropicUsage: Sendable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?
}

// MARK: - Service

final class KimiCodeAnthropicService: @unchecked Sendable {
    let baseURL: String
    private let network: (any NetworkProviding)?

    init(
        baseURL: String = "https://api.kimi.com/coding/v1",
        network: (any NetworkProviding)? = nil
    ) {
        self.baseURL = baseURL
        self.network = network
    }

    func makeRequest(apiKey: String, body: Data) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw KimiCodeAnthropicTransportError.invalidURL(baseURL)
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

    func send(
        apiKey: String,
        body: Data,
        onChunk: @Sendable @escaping (AnthropicKimiCodeEvent) async -> Bool
    ) async throws {
        guard let network else {
            throw KimiCodeAnthropicTransportError.networkUnavailable
        }
        let request = try makeRequest(apiKey: apiKey, body: body)
        let networkRequest = HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: request.httpBody,
            timeout: max(request.timeoutInterval, 300)
        )
        let accumulator = SSESequenceAccumulator()
        try await network.stream(
            networkRequest,
            onResponse: { _ in },
            onChunk: { data in
                for frame in accumulator.appendAndDrain(data) {
                    for event in KimiCodeAnthropicEventParser.parse(frame) {
                        if !(await onChunk(event)) { return false }
                    }
                }
                return true
            }
        )
        if let remaining = accumulator.drainRemaining() {
            for event in KimiCodeAnthropicEventParser.parse(remaining) {
                _ = await onChunk(event)
            }
        }
    }

    func sendOnce(apiKey: String, body: Data) async throws -> Data {
        guard let network else {
            throw KimiCodeAnthropicTransportError.networkUnavailable
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
            throw KimiCodeAnthropicTransportError.httpStatus(
                response.statusCode,
                response.bodyString ?? ""
            )
        }
        return response.body
    }
}

// MARK: - SSE Parser

enum KimiCodeAnthropicEventParser {
    static func parse(_ data: Data) -> [AnthropicKimiCodeEvent] {
        let text = String(decoding: data, as: UTF8.self)
        var events: [AnthropicKimiCodeEvent] = []
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

            if let eventType, eventType == "ping" { continue }

            if eventType == "error", let json = decode(payload) {
                let message = (json["error"] as? [String: Any])?["message"] as? String
                    ?? json["message"] as? String
                events.append(AnthropicKimiCodeEvent(error: message ?? "Kimi Code Anthropic error"))
                continue
            }

            guard let payload, let json = decode(payload) else { continue }

            switch eventType {
            case "message_start":
                let usage = parseUsage(json["message"] as? [String: Any])
                events.append(AnthropicKimiCodeEvent(usage: usage))
            case "content_block_start":
                let block = json["content_block"] as? [String: Any]
                if block?["type"] as? String == "tool_use" {
                    events.append(AnthropicKimiCodeEvent(
                        toolName: block?["name"] as? String,
                        toolID: block?["id"] as? String
                    ))
                }
            case "content_block_delta":
                let delta = json["delta"] as? [String: Any]
                let type = delta?["type"] as? String
                switch type {
                case "text_delta":
                    events.append(AnthropicKimiCodeEvent(textDelta: delta?["text"] as? String))
                case "thinking_delta":
                    events.append(AnthropicKimiCodeEvent(thinkingDelta: delta?["thinking"] as? String))
                case "signature_delta":
                    events.append(AnthropicKimiCodeEvent(thinkingSignature: delta?["signature"] as? String))
                case "input_json_delta":
                    events.append(AnthropicKimiCodeEvent(toolInputJSONDelta: delta?["partial_json"] as? String))
                default:
                    break
                }
            case "message_delta":
                let delta = json["delta"] as? [String: Any]
                let usage = parseUsage(json)
                events.append(AnthropicKimiCodeEvent(
                    stopReason: delta?["stop_reason"] as? String,
                    stopSequence: delta?["stop_sequence"] as? String,
                    usage: usage
                ))
            case "message_stop":
                events.append(AnthropicKimiCodeEvent(done: true))
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

    private static func parseUsage(_ json: [String: Any]?) -> KimiCodeAnthropicUsage? {
        guard let json, let usage = json["usage"] as? [String: Any] else { return nil }
        return KimiCodeAnthropicUsage(
            inputTokens: usage["input_tokens"] as? Int,
            outputTokens: usage["output_tokens"] as? Int,
            cacheReadInputTokens: usage["cache_read_input_tokens"] as? Int,
            cacheCreationInputTokens: usage["cache_creation_input_tokens"] as? Int
        )
    }
}
