import Combine
import SwiftUI
import Foundation
import OSLog

actor LLMService {
    static let shared = LLMService()
    private let logger = Logger(subsystem: "com.lumi.devassistant", category: "LLM")

    func sendMessage(messages: [ChatMessage], config: LLMConfig, tools: [AgentTool]? = nil) async throws -> ChatMessage {
        guard !config.apiKey.isEmpty else {
            throw NSError(domain: "LLMService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API Key is missing"])
        }

        switch config.provider {
        case .anthropic:
            return try await sendToAnthropic(messages: messages, apiKey: config.apiKey, model: config.model, tools: tools)
        case .openai, .deepseek, .zhipu:
            return try await sendToOpenAICompatible(messages: messages, config: config, tools: tools)
        }
    }

    // MARK: - OpenAI / DeepSeek

    private func sendToOpenAICompatible(messages: [ChatMessage], config: LLMConfig, tools: [AgentTool]?) async throws -> ChatMessage {
        guard let urlString = config.baseURL, let url = URL(string: urlString) else {
            throw NSError(domain: "LLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Base URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let conversationMessages = messages.map { msg -> [String: Any] in
            var dict: [String: Any] = [
                "role": msg.role.rawValue,
                "content": msg.content,
            ]
            if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                dict["tool_calls"] = toolCalls.map { tc in
                    [
                        "id": tc.id,
                        "type": "function",
                        "function": [
                            "name": tc.name,
                            "arguments": tc.arguments,
                        ],
                    ]
                }
                // OpenAI requires content to be null if tool_calls is present sometimes, but usually it's fine.
                // However, for tool_result (role=tool), we need tool_call_id
            }

            if msg.role.rawValue == "tool" { // We might need to map this role for OpenAI
                // Custom handling for tool results if we add a .tool case to MessageRole
                // Currently MessageRole only has user/assistant/system.
                // We'll map "user" with toolCallID to "tool" role for OpenAI
            }

            return dict
        }

        // Handle "tool" role mapping
        let finalMessages = messages.map { msg -> [String: Any] in
            if let toolCallID = msg.toolCallID {
                // This is a tool result
                return [
                    "role": "tool",
                    "tool_call_id": toolCallID,
                    "content": msg.content,
                ]
            } else {
                var dict: [String: Any] = [
                    "role": msg.role.rawValue,
                    "content": msg.content,
                ]
                if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                    dict["tool_calls"] = toolCalls.map { tc in
                        [
                            "id": tc.id,
                            "type": "function",
                            "function": [
                                "name": tc.name,
                                "arguments": tc.arguments,
                            ],
                        ]
                    }
                }
                return dict
            }
        }

        var body: [String: Any] = [
            "model": config.model,
            "messages": finalMessages,
            "stream": false,
        ]

        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { tool in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": tool.inputSchema,
                    ],
                ]
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            os_log(.error, "OpenAI API Error: %s", errorStr)
            throw NSError(domain: "LLMService", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorStr)"])
        }

        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String?
                    struct ToolCall: Decodable {
                        let id: String
                        let type: String
                        struct Function: Decodable {
                            let name: String
                            let arguments: String
                        }

                        let function: Function
                    }

                    let tool_calls: [ToolCall]?
                }

                let message: Message
            }

            let choices: [Choice]
        }

        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let choiceMessage = result.choices.first?.message

        let content = choiceMessage?.content ?? ""
        var toolCalls: [ToolCall]?

        if let apiToolCalls = choiceMessage?.tool_calls {
            toolCalls = apiToolCalls.map { tc in
                ToolCall(id: tc.id, name: tc.function.name, arguments: tc.function.arguments)
            }
        }

        return ChatMessage(role: .assistant, content: content, toolCalls: toolCalls)
    }

    // MARK: - Anthropic

    private func sendToAnthropic(messages: [ChatMessage], apiKey: String, model: String, tools: [AgentTool]?) async throws -> ChatMessage {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert Messages
        let systemMessage = messages.first(where: { $0.role == .system })?.content ?? ""

        let conversationMessages = messages.filter { $0.role != .system }.map { msg -> [String: Any] in
            if let toolCallID = msg.toolCallID {
                // Tool result
                return [
                    "role": "user",
                    "content": [
                        [
                            "type": "tool_result",
                            "tool_use_id": toolCallID,
                            "content": msg.content,
                        ],
                    ],
                ]
            } else if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                // Assistant message with tool calls
                var content: [[String: Any]] = []
                if !msg.content.isEmpty {
                    content.append(["type": "text", "text": msg.content])
                }
                for tc in toolCalls {
                    // Try to parse arguments string to object for Anthropic (it expects JSON object, not string)
                    let argsObject: Any
                    if let data = tc.arguments.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) {
                        argsObject = json
                    } else {
                        argsObject = [:] // Error fallback
                    }

                    content.append([
                        "type": "tool_use",
                        "id": tc.id,
                        "name": tc.name,
                        "input": argsObject,
                    ])
                }
                return ["role": "assistant", "content": content]
            } else {
                // Standard text message
                return [
                    "role": msg.role.rawValue,
                    "content": msg.content,
                ]
            }
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemMessage,
            "messages": conversationMessages,
        ]

        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": tool.inputSchema,
                ]
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            os_log(.error, "Anthropic API Error: %s", errorStr)
            throw NSError(domain: "LLMService", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorStr)"])
        }

        // Parse Anthropic Response
        // Structure: { content: [ { type: "text", text: "..." }, { type: "tool_use", ... } ] }
        struct AnthropicResponse: Decodable {
            struct Content: Decodable {
                let type: String
                let text: String?
                let id: String?
                let name: String?
                let input: [String: Any]? // Helper to capture raw dict

                enum CodingKeys: String, CodingKey {
                    case type, text, id, name, input
                }

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    type = try container.decode(String.self, forKey: .type)
                    text = try container.decodeIfPresent(String.self, forKey: .text)
                    id = try container.decodeIfPresent(String.self, forKey: .id)
                    name = try container.decodeIfPresent(String.self, forKey: .name)
                    // Custom decoding for input dictionary
                    if let inputContainer = try? container.decode([String: AnyCodable].self, forKey: .input) {
                        input = inputContainer.mapValues { $0.value }
                    } else {
                        input = nil
                    }
                }
            }

            let content: [Content]
        }

        // We need a AnyCodable helper
        let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        var textContent = ""
        var toolCalls: [ToolCall] = []

        for item in result.content {
            if item.type == "text", let text = item.text {
                textContent += text
            } else if item.type == "tool_use", let id = item.id, let name = item.name {
                let inputDict = item.input ?? [:]
                let inputData = try JSONSerialization.data(withJSONObject: inputDict)
                let inputString = String(data: inputData, encoding: .utf8) ?? "{}"
                toolCalls.append(ToolCall(id: id, name: name, arguments: inputString))
            }
        }

        return ChatMessage(role: .assistant, content: textContent, toolCalls: toolCalls.isEmpty ? nil : toolCalls)
    }
}

// Helper for decoding [String: Any]
struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Int.self) { value = x }
        else if let x = try? container.decode(Double.self) { value = x }
        else if let x = try? container.decode(String.self) { value = x }
        else if let x = try? container.decode(Bool.self) { value = x }
        else if let x = try? container.decode([String: AnyCodable].self) { value = x.mapValues { $0.value } }
        else if let x = try? container.decode([AnyCodable].self) { value = x.map { $0.value } }
        else { value = "" } // Fallback
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(DevAssistantPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
