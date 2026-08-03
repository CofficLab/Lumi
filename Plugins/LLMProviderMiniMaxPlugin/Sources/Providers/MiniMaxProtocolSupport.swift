import Foundation
import LumiKernel

enum MiniMaxProviderError: LocalizedError, LumiLLMErrorDispositionProviding {
    case invalidRequest(String)
    case invalidResponse(String)
    case api(statusCode: Int?, message: String)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case let .invalidRequest(message), let .invalidResponse(message), let .api(_, message): message
        case .networkUnavailable: "MiniMax network service is unavailable"
        }
    }

    var statusCode: Int? {
        if case let .api(statusCode, _) = self { return statusCode }
        return nil
    }

    var llmErrorDisposition: LumiLLMErrorDisposition {
        switch self {
        case .api(let statusCode, _) where statusCode == 401 || statusCode == 403 || statusCode == 400:
            return .nonRetryable
        case .api:
            return .retryable()
        default:
            return .nonRetryable
        }
    }
}

struct MiniMaxOpenAIEvent: Sendable {
    let content: String?
    let reasoning: String?
    let toolDeltas: [(id: String?, name: String?, arguments: String)]
    let stopReason: String?
    let done: Bool
    let error: String?
    let inputTokens: Int?
    let outputTokens: Int?
}

struct MiniMaxAnthropicEvent: Sendable {
    let text: String?
    let thinking: String?
    let toolID: String?
    let toolName: String?
    let toolArguments: String?
    let stopReason: String?
    let done: Bool
    let error: String?
}

final class MiniMaxOpenAIService: @unchecked Sendable {
    let url: URL
    private let network: (any NetworkProviding)?

    init(baseURL: String, network: (any NetworkProviding)?) throws {
        guard let url = URL(string: baseURL) else { throw MiniMaxProviderError.invalidRequest("Invalid MiniMax URL") }
        self.url = url
        self.network = network
    }

    func send(apiKey: String, body: Data, onEvent: @Sendable @escaping (MiniMaxOpenAIEvent) async -> Bool) async throws {
        guard let network else { throw MiniMaxProviderError.networkUnavailable }
        try await network.stream(
            HTTPRequest(url: url, method: .post, headers: [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json",
                "Accept": "text/event-stream",
            ], body: body, timeout: 300),
            onResponse: { _ in },
            onChunk: { data in
                for event in MiniMaxOpenAIEventParser.parse(data) {
                    if !(await onEvent(event)) { return false }
                }
                return true
            }
        )
    }

    func sendOnce(apiKey: String, body: Data) async throws -> Data {
        guard let network else { throw MiniMaxProviderError.networkUnavailable }
        let response = try await network.request(HTTPRequest(url: url, method: .post, headers: [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
        ], body: body, timeout: 60))
        guard response.isSuccess else { throw MiniMaxProviderError.api(statusCode: response.statusCode, message: response.bodyString ?? "") }
        return response.body
    }
}

final class MiniMaxAnthropicService: @unchecked Sendable {
    let url: URL
    private let network: (any NetworkProviding)?

    init(baseURL: String, network: (any NetworkProviding)?) throws {
        guard let url = URL(string: baseURL) else { throw MiniMaxProviderError.invalidRequest("Invalid MiniMax Anthropic URL") }
        self.url = url
        self.network = network
    }

    func send(apiKey: String, body: Data, onEvent: @Sendable @escaping (MiniMaxAnthropicEvent) async -> Bool) async throws {
        guard let network else { throw MiniMaxProviderError.networkUnavailable }
        try await network.stream(
            HTTPRequest(url: url, method: .post, headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "Content-Type": "application/json",
                "Accept": "text/event-stream",
            ], body: body, timeout: 300),
            onResponse: { _ in },
            onChunk: { data in
                for event in MiniMaxAnthropicEventParser.parse(data) {
                    if !(await onEvent(event)) { return false }
                }
                return true
            }
        )
    }
}

enum MiniMaxOpenAIEventParser {
    static func parse(_ data: Data) -> [MiniMaxOpenAIEvent] {
        let text = String(decoding: data, as: UTF8.self)
        return text.components(separatedBy: "\n").compactMap { line in
            guard line.hasPrefix("data:") else { return nil }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            if payload == "[DONE]" { return MiniMaxOpenAIEvent(content: nil, reasoning: nil, toolDeltas: [], stopReason: nil, done: true, error: nil, inputTokens: nil, outputTokens: nil) }
            guard let json = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else { return nil }
            if let error = json["error"] as? [String: Any] { return MiniMaxOpenAIEvent(content: nil, reasoning: nil, toolDeltas: [], stopReason: nil, done: false, error: error["message"] as? String, inputTokens: nil, outputTokens: nil) }
            let choice = (json["choices"] as? [[String: Any]])?.first
            let delta = choice?["delta"] as? [String: Any]
            let deltas = (delta?["tool_calls"] as? [[String: Any]] ?? []).map { item in
                let function = item["function"] as? [String: Any]
                return (item["id"] as? String, function?["name"] as? String, function?["arguments"] as? String ?? "")
            }
            let usage = json["usage"] as? [String: Any]
            return MiniMaxOpenAIEvent(content: delta?["content"] as? String, reasoning: delta?["reasoning_content"] as? String ?? delta?["reasoning"] as? String, toolDeltas: deltas, stopReason: choice?["finish_reason"] as? String, done: false, error: nil, inputTokens: usage?["prompt_tokens"] as? Int, outputTokens: usage?["completion_tokens"] as? Int)
        }
    }
}

enum MiniMaxAnthropicEventParser {
    static func parse(_ data: Data) -> [MiniMaxAnthropicEvent] {
        let text = String(decoding: data, as: UTF8.self)
        return text.components(separatedBy: "\n\n").compactMap { frame in
            let lines = frame.components(separatedBy: "\n")
            let type = lines.first(where: { $0.hasPrefix("event:") })?.dropFirst(6).trimmingCharacters(in: .whitespaces)
            guard let dataLine = lines.first(where: { $0.hasPrefix("data:") }) else {
                return type == "message_stop" ? MiniMaxAnthropicEvent(text: nil, thinking: nil, toolID: nil, toolName: nil, toolArguments: nil, stopReason: nil, done: true, error: nil) : nil
            }
            let payload = dataLine.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let json = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else { return nil }
            if type == "error" { return MiniMaxAnthropicEvent(text: nil, thinking: nil, toolID: nil, toolName: nil, toolArguments: nil, stopReason: nil, done: false, error: (json["error"] as? [String: Any])?["message"] as? String) }
            if type == "message_stop" { return MiniMaxAnthropicEvent(text: nil, thinking: nil, toolID: nil, toolName: nil, toolArguments: nil, stopReason: nil, done: true, error: nil) }
            if type == "content_block_start", let block = json["content_block"] as? [String: Any], block["type"] as? String == "tool_use" { return MiniMaxAnthropicEvent(text: nil, thinking: nil, toolID: block["id"] as? String, toolName: block["name"] as? String, toolArguments: nil, stopReason: nil, done: false, error: nil) }
            let delta = json["delta"] as? [String: Any]
            switch delta?["type"] as? String {
            case "text_delta": return MiniMaxAnthropicEvent(text: delta?["text"] as? String, thinking: nil, toolID: nil, toolName: nil, toolArguments: nil, stopReason: nil, done: false, error: nil)
            case "thinking_delta": return MiniMaxAnthropicEvent(text: nil, thinking: delta?["thinking"] as? String, toolID: nil, toolName: nil, toolArguments: nil, stopReason: nil, done: false, error: nil)
            case "input_json_delta": return MiniMaxAnthropicEvent(text: nil, thinking: nil, toolID: nil, toolName: nil, toolArguments: delta?["partial_json"] as? String, stopReason: nil, done: false, error: nil)
            default: return MiniMaxAnthropicEvent(text: nil, thinking: nil, toolID: nil, toolName: nil, toolArguments: nil, stopReason: (delta?["stop_reason"] as? String) ?? ((json["delta"] as? [String: Any])?["stop_reason"] as? String), done: false, error: nil)
            }
        }
    }
}

enum MiniMaxRequestBuilder {
    static func openAI(_ request: LumiLLMRequest) -> [String: Any] {
        var body: [String: Any] = ["model": request.model, "messages": request.messages.compactMap(openAIMessage), "stream": true]
        if !request.tools.isEmpty { body["tools"] = request.tools.map { ["type": "function", "function": ["name": $0.name, "description": $0.toolDescription, "parameters": $0.inputSchema.anyValue]] } }
        if let effort = request.generationOptions.reasoningEffort { body["reasoning_effort"] = effort.rawValue }
        return body
    }

    static func anthropic(_ request: LumiLLMRequest) -> [String: Any] {
        let system = request.messages.filter { $0.role == .system }.map(\.content).filter { !$0.isEmpty }.joined(separator: "\n\n")
        var body: [String: Any] = ["model": request.model, "max_tokens": 8192, "messages": anthropicMessages(request.messages), "stream": true]
        if !system.isEmpty { body["system"] = system }
        if !request.tools.isEmpty { body["tools"] = request.tools.map { ["name": $0.name, "description": $0.toolDescription, "input_schema": $0.inputSchema.anyValue] } }
        return body
    }

    private static func openAIMessage(_ message: LumiChatMessage) -> [String: Any]? {
        switch message.role {
        case .system, .user: return ["role": message.role.rawValue, "content": message.content]
        case .assistant:
            var value: [String: Any] = ["role": "assistant", "content": message.content]
            if let calls = message.toolCalls { value["tool_calls"] = calls.map { ["id": $0.id, "type": "function", "function": ["name": $0.name, "arguments": $0.arguments]] } }
            return value
        case .tool: guard let id = message.toolCallID else { return nil }; return ["role": "tool", "tool_call_id": id, "content": message.content]
        case .error, .status: return nil
        }
    }

    private static func anthropicMessages(_ messages: [LumiChatMessage]) -> [[String: Any]] {
        var output: [[String: Any]] = []
        for message in messages where message.role != .system && message.role != .error && message.role != .status {
            switch message.role {
            case .user: output.append(["role": "user", "content": [["type": "text", "text": message.content]]])
            case .assistant:
                var blocks: [[String: Any]] = message.content.isEmpty ? [] : [["type": "text", "text": message.content]]
                blocks += (message.toolCalls ?? []).map { ["type": "tool_use", "id": $0.id, "name": $0.name, "input": parseJSON($0.arguments)] }
                if !blocks.isEmpty { output.append(["role": "assistant", "content": blocks]) }
            case .tool:
                guard let id = message.toolCallID else { continue }
                if let last = output.last, last["role"] as? String == "user", var blocks = last["content"] as? [[String: Any]], blocks.contains(where: { $0["type"] as? String == "tool_result" }) { blocks.append(["type": "tool_result", "tool_use_id": id, "content": message.content]); output[output.count - 1] = ["role": "user", "content": blocks] } else { output.append(["role": "user", "content": [["type": "tool_result", "tool_use_id": id, "content": message.content]]]) }
            default: break
            }
        }
        return output
    }

    private static func parseJSON(_ text: String) -> [String: Any] { guard let data = text.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }; return object }
}
