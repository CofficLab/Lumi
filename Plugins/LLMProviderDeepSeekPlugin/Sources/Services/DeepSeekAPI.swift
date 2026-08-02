import Foundation
import LumiKernel

/// DeepSeek-specific transport, request encoding, SSE parsing, and usage parsing.
/// This intentionally does not depend on the generic OpenAI-compatible LLMKit layer.
final class DeepSeekAPIService: @unchecked Sendable {
    let baseURL: String
    private let network: (any NetworkProviding)?

    init(
        baseURL: String = "https://api.deepseek.com/v1/chat/completions",
        network: (any NetworkProviding)? = nil
    ) {
        self.baseURL = baseURL
        self.network = network
    }

    func send(
        request: URLRequest,
        body: [String: Any],
        onChunk: @Sendable @escaping (DeepSeekEvent) async -> Bool
    ) async throws {
        guard let network else {
            throw DeepSeekTransportError.networkUnavailable
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let networkRequest = HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: bodyData,
            timeout: max(request.timeoutInterval, 300)
        )
        try await network.stream(
            networkRequest,
            onResponse: { _ in },
            onChunk: { data in
                for event in DeepSeekEventParser.parse(data) {
                    if !(await onChunk(event)) { return false }
                }
                return true
            }
        )
    }

    func sendOnce(request: URLRequest, body: [String: Any]) async throws -> Data {
        guard let network else {
            throw DeepSeekTransportError.networkUnavailable
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let response = try await network.request(HTTPRequest(
            url: request.url!,
            method: .post,
            headers: request.allHTTPHeaderFields ?? [:],
            body: bodyData,
            timeout: request.timeoutInterval
        ))
        guard response.isSuccess else {
            throw DeepSeekTransportError.httpStatus(response.statusCode, response.bodyString ?? "")
        }
        return response.body
    }
}

enum DeepSeekTransportError: LocalizedError {
    case networkUnavailable
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: "DeepSeek network service is unavailable"
        case let .httpStatus(code, body): "HTTP \(code): \(body)"
        }
    }
}

enum DeepSeekEventParser {
    static func parse(_ data: Data) -> [DeepSeekEvent] {
        let text = String(decoding: data, as: UTF8.self)
        return text
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("data:") }
            .compactMap { line in
                let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                if payload == "[DONE]" {
                    return DeepSeekEvent(content: nil, reasoning: nil, toolDeltas: [], stopReason: nil, done: true, error: nil, inputTokens: nil, outputTokens: nil, cacheHitTokens: nil, cacheTotalInputTokens: nil)
                }
                guard let jsonData = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                else { return nil }

                if let error = json["error"] as? [String: Any] {
                    return DeepSeekEvent(content: nil, reasoning: nil, toolDeltas: [], stopReason: nil, done: false, error: error["message"] as? String, inputTokens: nil, outputTokens: nil, cacheHitTokens: nil, cacheTotalInputTokens: nil)
                }

                let usage = json["usage"] as? [String: Any]
                let hit = usage?["prompt_cache_hit_tokens"] as? Int
                let miss = usage?["prompt_cache_miss_tokens"] as? Int
                let total = hit.flatMap { h in miss.map { h + $0 } } ?? usage?["prompt_tokens"] as? Int
                let choice = (json["choices"] as? [[String: Any]])?.first
                let delta = choice?["delta"] as? [String: Any]
                let toolDeltas = (delta?["tool_calls"] as? [[String: Any]] ?? []).map { item in
                    let function = item["function"] as? [String: Any]
                    return DeepSeekToolDelta(
                        id: item["id"] as? String,
                        name: function?["name"] as? String,
                        arguments: function?["arguments"] as? String ?? ""
                    )
                }
                return DeepSeekEvent(
                    content: delta?["content"] as? String,
                    reasoning: delta?["reasoning_content"] as? String,
                    toolDeltas: toolDeltas,
                    stopReason: choice?["finish_reason"] as? String,
                    done: false,
                    error: nil,
                    inputTokens: total,
                    outputTokens: usage?["completion_tokens"] as? Int,
                    cacheHitTokens: hit,
                    cacheTotalInputTokens: total
                )
            }
    }
}

actor DeepSeekStreamState {
    var content = ""
    var reasoning = ""
    var toolCalls: [LumiToolCall] = []
    var activeToolID: String?
    var activeToolName: String?
    var activeToolArguments = ""
    var inputTokens: Int?
    var outputTokens: Int?
    var cacheHitTokens: Int?
    var cacheTotalInputTokens: Int?
    var stopReason: String?
    var error: String?

    func setError(_ value: String) { error = value }

    func append(_ event: DeepSeekEvent) {
        if let value = event.content { content += value }
        if let value = event.reasoning { reasoning += value }
        if let value = event.inputTokens { inputTokens = value }
        if let value = event.outputTokens { outputTokens = value }
        if let value = event.cacheHitTokens { cacheHitTokens = value }
        if let value = event.cacheTotalInputTokens { cacheTotalInputTokens = value }
        if let value = event.stopReason { stopReason = value }

        for delta in event.toolDeltas {
            let id = delta.id
            let name = delta.name
            let arguments = delta.arguments
            if id != nil || name != nil {
                saveTool()
                activeToolID = id ?? UUID().uuidString
                activeToolName = name ?? ""
                activeToolArguments = arguments
            } else {
                activeToolArguments += arguments
            }
        }
    }

    func saveTool() {
        guard let id = activeToolID, let name = activeToolName else { return }
        toolCalls.append(LumiToolCall(id: id, name: name, arguments: activeToolArguments.isEmpty ? "{}" : activeToolArguments))
        activeToolID = nil
        activeToolName = nil
        activeToolArguments = ""
    }
}

enum DeepSeekRequestBuilder {
    static func body(for request: LumiLLMRequest) -> [String: Any] {
        var body: [String: Any] = [
            "model": request.model,
            "messages": request.messages.compactMap(message),
            "stream": true,
        ]
        if !request.tools.isEmpty {
            body["tools"] = request.tools.map { tool in
                ["type": "function", "function": [
                    "name": tool.name,
                    "description": tool.toolDescription,
                    "parameters": tool.inputSchema.anyValue,
                ]]
            }
        }
        if let effort = request.generationOptions.reasoningEffort {
            body["reasoning_effort"] = effort.rawValue
        }
        return body
    }

    private static func message(_ message: LumiChatMessage) -> [String: Any]? {
        switch message.role {
        case .system, .user:
            return ["role": message.role.rawValue, "content": message.content]
        case .assistant:
            var value: [String: Any] = ["role": "assistant", "content": message.content]
            if let calls = message.toolCalls, !calls.isEmpty {
                value["tool_calls"] = calls.map { [
                    "id": $0.id,
                    "type": "function",
                    "function": ["name": $0.name, "arguments": $0.arguments],
                ] }
            }
            return value
        case .tool:
            guard let id = message.toolCallID else { return nil }
            return ["role": "tool", "tool_call_id": id, "content": message.content]
        case .error, .status:
            return nil
        }
    }
}
