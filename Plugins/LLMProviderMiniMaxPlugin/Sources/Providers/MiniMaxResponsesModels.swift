import Foundation

// MARK: - Request Models

/// Request body for MiniMax Responses API
struct MiniMaxResponsesRequest: Encodable {
    let model: String
    let input: MiniMaxResponsesInput
    let instructions: String?
    let maxOutputTokens: Int?
    let temperature: Double?
    let topP: Double?
    let stream: Bool
    let tools: [MiniMaxResponsesTool]?
    let toolChoice: String?
    let reasoning: MiniMaxResponsesReasoning?
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case model, input, instructions, tools, metadata
        case maxOutputTokens = "max_output_tokens"
        case temperature
        case topP = "top_p"
        case stream
        case toolChoice = "tool_choice"
        case reasoning
    }
}

enum MiniMaxResponsesInput: Encodable {
    case simple(String)
    case history([MiniMaxResponsesInputItem])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .simple(let text):
            try container.encode(text)
        case .history(let items):
            try container.encode(items)
        }
    }
}

struct MiniMaxResponsesInputItem: Encodable {
    let type: String
    let role: String?
    let content: String?
    let callID: String?
    let name: String?
    let arguments: String?
    let output: String?

    enum CodingKeys: String, CodingKey {
        case type, role, content, name, arguments, output
        case callID = "call_id"
    }

    init(role: String, content: String) {
        self.type = "message"
        self.role = role
        self.content = content
        self.callID = nil
        self.name = nil
        self.arguments = nil
        self.output = nil
    }

    init(functionCall callID: String, name: String, arguments: String) {
        self.type = "function_call"
        self.role = nil
        self.content = nil
        self.callID = callID
        self.name = name
        self.arguments = arguments
        self.output = nil
    }

    init(functionCallOutput callID: String, output: String) {
        self.type = "function_call_output"
        self.role = nil
        self.content = nil
        self.callID = callID
        self.name = nil
        self.arguments = nil
        self.output = output
    }
}

struct MiniMaxResponsesTool: Encodable {
    let type: String
    let name: String
    let description: String?
    let parameters: AnyCodableValue

    init(name: String, description: String?, parameters: [String: Any]) {
        self.type = "function"
        self.name = name
        self.description = description
        self.parameters = AnyCodableValue(parameters)
    }
}

struct MiniMaxResponsesReasoning: Encodable {
    let effort: String

    init(effort: String) {
        self.effort = effort
    }
}

// MARK: - Response Models

struct MiniMaxResponsesResponse: Decodable {
    let id: String
    let object: String
    let createdAt: Int
    let model: String
    let status: String
    let output: [MiniMaxResponsesOutputItem]?
    let outputText: String?
    let usage: MiniMaxResponsesUsage?
    let error: MiniMaxResponsesError?

    enum CodingKeys: String, CodingKey {
        case id, object, model, status, output, usage, error
        case createdAt = "created_at"
        case outputText = "output_text"
    }
}

struct MiniMaxResponsesOutputItem: Decodable {
    let id: String
    let type: String
    let status: String?
    let role: String?
    let content: [MiniMaxResponsesOutputContent]?
    let summary: [MiniMaxResponsesSummary]?
    let callID: String?
    let name: String?
    let arguments: String?

    enum CodingKeys: String, CodingKey {
        case id, type, status, role, content, summary, name, arguments
        case callID = "call_id"
    }
}

struct MiniMaxResponsesOutputContent: Decodable {
    let type: String
    let text: String?
    let annotations: [String]?
}

struct MiniMaxResponsesSummary: Decodable {
    let type: String
    let text: String?
}

struct MiniMaxResponsesUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let inputTokensDetails: InputTokensDetails?
    let outputTokensDetails: OutputTokensDetails?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
        case inputTokensDetails = "input_tokens_details"
        case outputTokensDetails = "output_tokens_details"
    }
}

struct InputTokensDetails: Decodable {
    let cachedTokens: Int?

    enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
    }
}

struct OutputTokensDetails: Decodable {
    let reasoningTokens: Int?

    enum CodingKeys: String, CodingKey {
        case reasoningTokens = "reasoning_tokens"
    }
}

struct MiniMaxResponsesError: Decodable {
    let code: String?
    let message: String?
}

// MARK: - Streaming Event Models

/// Represents a parsed SSE event from the Responses API stream
struct MiniMaxResponsesEvent: Sendable {
    enum EventType: String {
        case textDelta = "text_delta"
        case reasoningDelta = "reasoning_delta"
        case functionCall = "function_call"
        case done = "done"
        case error = "error"
        case unknown
    }

    let type: EventType
    let text: String?
    let reasoning: String?
    let callID: String?
    let name: String?
    let arguments: String?
    let stopReason: String?
    let isDone: Bool
    let error: String?
    let usage: MiniMaxResponsesUsage?
}

// MARK: - SSE Parser

enum MiniMaxResponsesEventParser {
    static func parse(_ data: Data) -> [MiniMaxResponsesEvent] {
        let text = String(decoding: data, as: UTF8.self)
        return text.components(separatedBy: "\n\n").compactMap { frame -> MiniMaxResponsesEvent? in
            let lines = frame.components(separatedBy: "\n")
            let eventType = lines.first(where: { $0.hasPrefix("event:") })?.dropFirst(6).trimmingCharacters(in: .whitespaces)
            guard let dataLine = lines.first(where: { $0.hasPrefix("data:") }) else {
                if eventType == "[DONE]" || eventType == "done" {
                    return MiniMaxResponsesEvent(type: .done, text: nil, reasoning: nil, callID: nil, name: nil, arguments: nil, stopReason: nil, isDone: true, error: nil, usage: nil)
                }
                return nil
            }
            let payload = dataLine.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let json = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else { return nil }

            if eventType == "error" {
                let err = json["error"] as? [String: Any]
                return MiniMaxResponsesEvent(type: .error, text: nil, reasoning: nil, callID: nil, name: nil, arguments: nil, stopReason: nil, isDone: false, error: err?["message"] as? String, usage: nil)
            }

            // Parse text_delta
            if let delta = json["delta"] as? [String: Any] {
                switch delta["type"] as? String {
                case "text_delta":
                    return MiniMaxResponsesEvent(type: .textDelta, text: delta["text"] as? String, reasoning: nil, callID: nil, name: nil, arguments: nil, stopReason: nil, isDone: false, error: nil, usage: nil)
                case "reasoning_delta":
                    return MiniMaxResponsesEvent(type: .reasoningDelta, text: nil, reasoning: delta["text"] as? String, callID: nil, name: nil, arguments: nil, stopReason: nil, isDone: false, error: nil, usage: nil)
                case "function_call":
                    let callID = delta["call_id"] as? String
                    let name = delta["name"] as? String
                    let arguments = delta["arguments"] as? String
                    return MiniMaxResponsesEvent(type: .functionCall, text: nil, reasoning: nil, callID: callID, name: name, arguments: arguments, stopReason: nil, isDone: false, error: nil, usage: nil)
                default:
                    break
                }
            }

            // Parse done event (done with usage)
            if eventType == "done" {
                let usageDict = json["usage"] as? [String: Any]
                var usage: MiniMaxResponsesUsage?
                if let usageDict {
                    usage = MiniMaxResponsesUsage(
                        inputTokens: usageDict["input_tokens"] as? Int ?? 0,
                        outputTokens: usageDict["output_tokens"] as? Int ?? 0,
                        totalTokens: usageDict["total_tokens"] as? Int ?? 0,
                        inputTokensDetails: nil,
                        outputTokensDetails: nil
                    )
                }
                return MiniMaxResponsesEvent(type: .done, text: nil, reasoning: nil, callID: nil, name: nil, arguments: nil, stopReason: json["stop_reason"] as? String, isDone: true, error: nil, usage: usage)
            }

            return nil
        }
    }
}

// MARK: - Helper

/// Wraps an arbitrary JSON value for encoding
struct AnyCodableValue: Encodable {
    private let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let dict = value as? [String: Any] {
            try container.encode(AnyCodableDictionary(dict))
        } else if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}

struct AnyCodableDictionary: Encodable {
    private let dict: [String: Any]

    init(_ dict: [String: Any]) {
        self.dict = dict
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONCodingKeys.self)
        for (key, value) in dict {
            let codingKey = JSONCodingKeys(stringValue: key)!
            if let string = value as? String {
                try container.encode(string, forKey: codingKey)
            } else if let int = value as? Int {
                try container.encode(int, forKey: codingKey)
            } else if let double = value as? Double {
                try container.encode(double, forKey: codingKey)
            } else if let bool = value as? Bool {
                try container.encode(bool, forKey: codingKey)
            } else if let nestedDict = value as? [String: Any] {
                try container.encode(AnyCodableDictionary(nestedDict), forKey: codingKey)
            } else if let array = value as? [[String: Any]] {
                try container.encode(array.map { AnyCodableDictionary($0) }, forKey: codingKey)
            }
        }
    }
}

struct JSONCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int? { Int(stringValue) }

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.stringValue = "\(intValue)" }
}
