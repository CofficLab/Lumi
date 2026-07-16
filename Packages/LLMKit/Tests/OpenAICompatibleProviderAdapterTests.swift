import XCTest
@testable import LLMKit

final class OpenAICompatibleProviderAdapterTests: XCTestCase {
    func testBuildRequestSetsMethodAuthContentTypeAndAdditionalHeaders() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: .init(
                baseURL: "https://example.com/v1/chat/completions",
                additionalHeaders: [
                    "HTTP-Referer": "ExampleApp",
                    "X-Title": "ExampleApp",
                ]
            )
        )

        let request = adapter.buildRequest(
            url: try XCTUnwrap(URL(string: adapter.configuration.baseURL)),
            apiKey: "secret"
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "HTTP-Referer"), "ExampleApp")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Title"), "ExampleApp")
    }

    func testBuildRequestBodyIncludesMessagesAndStreamFalse() throws {
        let adapter = makeAdapter()
        let messages = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi"),
        ]

        let body = try adapter.buildRequestBody(
            messages: messages,
            model: "gpt-4o",
            tools: nil,
            systemPrompt: ""
        )

        XCTAssertEqual(body["model"] as? String, "gpt-4o")
        XCTAssertEqual(body["stream"] as? Bool, false)
        XCTAssertNil(body["tools"])

        let encodedMessages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(encodedMessages.count, 2)
        XCTAssertEqual(encodedMessages[0]["role"] as? String, "user")
        XCTAssertEqual(encodedMessages[0]["content"] as? String, "Hello")
        XCTAssertEqual(encodedMessages[1]["role"] as? String, "assistant")
        XCTAssertEqual(encodedMessages[1]["content"] as? String, "Hi")
    }

    func testBuildRequestBodyPrependsSystemPromptWhenMissing() throws {
        let adapter = makeAdapter()

        let body = try adapter.buildRequestBody(
            messages: [ChatMessage(role: .user, content: "Hello")],
            model: "gpt-4o",
            tools: nil,
            systemPrompt: "Be concise"
        )

        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[0]["content"] as? String, "Be concise")
        XCTAssertEqual(messages[1]["role"] as? String, "user")
    }

    func testBuildRequestBodyDoesNotDuplicateExistingSystemPrompt() throws {
        let adapter = makeAdapter()

        let body = try adapter.buildRequestBody(
            messages: [
                ChatMessage(role: .system, content: "Existing"),
                ChatMessage(role: .user, content: "Hello"),
            ],
            model: "gpt-4o",
            tools: nil,
            systemPrompt: "New"
        )

        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[0]["content"] as? String, "Existing")
    }

    func testBuildRequestBodyFormatsTools() throws {
        let adapter = makeAdapter()
        let tool = MockTool(
            name: "read_file",
            toolDescription: "Read a file",
            inputSchema: [
                "type": "object",
                "properties": ["path": ["type": "string"]],
            ]
        )

        let body = try adapter.buildRequestBody(
            messages: [ChatMessage(role: .user, content: "Read")],
            model: "gpt-4o",
            tools: [tool],
            systemPrompt: ""
        )

        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools[0]["type"] as? String, "function")

        let function = try XCTUnwrap(tools[0]["function"] as? [String: Any])
        XCTAssertEqual(function["name"] as? String, "read_file")
        XCTAssertEqual(function["description"] as? String, "Read a file")

        let parameters = try XCTUnwrap(function["parameters"] as? [String: Any])
        XCTAssertEqual(parameters["type"] as? String, "object")
    }

    func testBuildStreamingRequestBodySetsStreamTrueAndUsageOptionWhenConfigured() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: .init(
                baseURL: "https://example.com",
                includeUsageInStreamOptions: true
            )
        )

        let body = try adapter.buildStreamingRequestBody(
            messages: [ChatMessage(role: .user, content: "Hello")],
            model: "gpt-4o",
            tools: nil,
            systemPrompt: ""
        )

        XCTAssertEqual(body["stream"] as? Bool, true)
        let streamOptions = try XCTUnwrap(body["stream_options"] as? [String: Bool])
        XCTAssertEqual(streamOptions["include_usage"], true)
    }

    func testTransformToolResultMessage() {
        let adapter = makeAdapter()

        let message = adapter.transformMessage(
            ChatMessage(role: .tool, content: "result", toolCallID: "call_123")
        )

        XCTAssertEqual(message["role"] as? String, "tool")
        XCTAssertEqual(message["tool_call_id"] as? String, "call_123")
        XCTAssertEqual(message["content"] as? String, "result")
    }

    func testTransformAssistantMessageWithToolCalls() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: .init(
                baseURL: "https://example.com",
                includesReasoningContentInMessages: true
            )
        )

        let message = adapter.transformMessage(
            ChatMessage(
                role: .assistant,
                content: "",
                toolCalls: [
                    ToolCall(id: "call_123", name: "read_file", arguments: #"{"path":"README.md"}"#),
                ],
                reasoningContent: "Need to inspect the file first."
            )
        )

        XCTAssertEqual(message["role"] as? String, "assistant")
        XCTAssertEqual(message["reasoning_content"] as? String, "Need to inspect the file first.")
        let toolCalls = try XCTUnwrap(message["tool_calls"] as? [[String: Any]])
        XCTAssertEqual(toolCalls.count, 1)
        XCTAssertEqual(toolCalls[0]["id"] as? String, "call_123")
        XCTAssertEqual(toolCalls[0]["type"] as? String, "function")

        let function = try XCTUnwrap(toolCalls[0]["function"] as? [String: String])
        XCTAssertEqual(function["name"], "read_file")
        XCTAssertEqual(function["arguments"], #"{"path":"README.md"}"#)
    }

    func testTransformAssistantMessageOmitsReasoningContentByDefault() {
        let message = makeAdapter().transformMessage(
            ChatMessage(
                role: .assistant,
                content: "Done",
                reasoningContent: "Internal reasoning"
            )
        )

        XCTAssertNil(message["reasoning_content"])
    }

    func testParseResponseReturnsContentAndToolCalls() throws {
        let adapter = makeAdapter()
        let data = Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "Done",
                    "tool_calls": [
                      {
                        "id": "call_123",
                        "type": "function",
                        "function": {
                          "name": "read_file",
                          "arguments": "{\\"path\\":\\"README.md\\"}"
                        }
                      }
                    ],
                    "reasoning_content": "Need to inspect the file first."
                  }
                }
              ]
            }
            """.utf8
        )

        let result = try adapter.parseResponse(data: data)

        XCTAssertEqual(result.content, "Done")
        XCTAssertEqual(
            result.toolCalls,
            [ToolCall(id: "call_123", name: "read_file", arguments: #"{"path":"README.md"}"#)]
        )
        XCTAssertEqual(result.reasoningContent, "Need to inspect the file first.")
    }

    func testParseResponseUsesEmptyContentWhenContentIsNull() throws {
        let adapter = makeAdapter()
        let data = Data(#"{"choices":[{"message":{"content":null}}]}"#.utf8)

        let result = try adapter.parseResponse(data: data)

        XCTAssertEqual(result.content, "")
        XCTAssertNil(result.toolCalls)
    }

    func testParseResponseThrowsNoChoices() {
        let adapter = makeAdapter()
        let data = Data(#"{"choices":[]}"#.utf8)

        XCTAssertThrowsError(try adapter.parseResponse(data: data)) { error in
            XCTAssertEqual(error as? OpenAICompatibleProviderError, .noChoices)
        }
    }

    func testParseResponseThrowsAPIError() {
        let adapter = makeAdapter()
        let data = Data(#"{"error":{"message":"Invalid API key"}}"#.utf8)

        XCTAssertThrowsError(try adapter.parseResponse(data: data)) { error in
            XCTAssertEqual(error as? OpenAICompatibleProviderError, .apiError(message: "Invalid API key"))
        }
    }

    func testParseStreamTextDelta() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data(#"data: {"choices":[{"delta":{"content":"Hello"}}]}"#.utf8)
        )

        XCTAssertEqual(chunk, StreamChunk(content: "Hello", eventType: .textDelta))
    }

    func testParseStreamReasoningContentDelta() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data(#"data: {"choices":[{"delta":{"reasoning_content":"Thinking"}}]}"#.utf8)
        )

        XCTAssertEqual(chunk, StreamChunk(content: "Thinking", eventType: .thinkingDelta))
    }

    func testParseStreamDone() throws {
        let chunk = try makeAdapter().parseStreamChunk(data: Data("data: [DONE]\n\n".utf8))

        XCTAssertEqual(chunk, StreamChunk(isDone: true))
    }

    func testParseStreamError() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data(#"data: {"error":{"message":"Rate limited"}}"#.utf8)
        )

        XCTAssertEqual(chunk, StreamChunk(error: "Rate limited"))
    }

    func testParseStreamUsage() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data(#"data: {"usage":{"prompt_tokens":7,"completion_tokens":11}}"#.utf8)
        )

        XCTAssertEqual(chunk, StreamChunk(inputTokens: 7, outputTokens: 11))
    }

    func testParseStreamToolCallStart() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data(
                #"data: {"choices":[{"delta":{"tool_calls":[{"id":"call_123","function":{"name":"read_file","arguments":"{\"path\""}}]}}]}"#.utf8
            )
        )

        XCTAssertEqual(
            chunk,
            StreamChunk(
                toolCalls: [ToolCall(id: "call_123", name: "read_file", arguments: #"{"path""#)],
                partialJson: #"{"path""#,
                eventType: .contentBlockStart
            )
        )
    }

    func testParseStreamToolArgumentsDelta() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data(
                #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":":\"README.md\"}"}}]}}]}"#.utf8
            )
        )

        XCTAssertEqual(
            chunk,
            StreamChunk(
                partialJson: #":"README.md"}"#,
                eventType: .inputJsonDelta
            )
        )
    }

    func testParseStreamFunctionScopedToolCallIDWhenConfigured() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: .init(
                baseURL: "https://example.com",
                acceptsFunctionScopedToolCallID: true
            )
        )

        let chunk = try adapter.parseStreamChunk(
            data: Data(
                #"data: {"choices":[{"delta":{"tool_calls":[{"function":{"id":"call_nested","name":"read_file","arguments":"{}"}}]}}]}"#.utf8
            )
        )

        XCTAssertEqual(
            chunk,
            StreamChunk(
                toolCalls: [ToolCall(id: "call_nested", name: "read_file", arguments: "{}")],
                partialJson: "{}",
                eventType: .contentBlockStart
            )
        )
    }

    func testParseStreamIgnoresFunctionScopedToolCallIDByDefault() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data(
                #"data: {"choices":[{"delta":{"tool_calls":[{"function":{"id":"call_nested","name":"read_file","arguments":"{}"}}]}}]}"#.utf8
            )
        )

        XCTAssertEqual(
            chunk,
            StreamChunk(
                partialJson: "{}",
                eventType: .inputJsonDelta
            )
        )
    }

    func testParseStreamReturnsEmptyChunkWhenConfiguredAndNoDeltaExists() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: .init(
                baseURL: "https://example.com",
                returnsEmptyChunkWhenNoDelta: true
            )
        )

        let chunk = try adapter.parseStreamChunk(data: Data(#"data: {"choices":[{"delta":{}}]}"#.utf8))

        XCTAssertEqual(chunk, StreamChunk(content: "", eventType: .textDelta))
    }

    func testParseStreamReturnsNilForMalformedJSON() throws {
        let chunk = try makeAdapter().parseStreamChunk(data: Data("data: {invalid".utf8))

        XCTAssertNil(chunk)
    }

    func testParseStreamReturnsNilForNonDataSSEEvent() throws {
        let chunk = try makeAdapter().parseStreamChunk(data: Data("event: ping\n\n".utf8))

        XCTAssertNil(chunk)
    }

    func testParseStreamSupportsDataLineWithoutSpace() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data(#"data:{"choices":[{"delta":{"content":"Hello"}}]}"#.utf8)
        )

        XCTAssertEqual(chunk, StreamChunk(content: "Hello", eventType: .textDelta))
    }

    private func makeAdapter() -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            configuration: .init(baseURL: "https://example.com/v1/chat/completions")
        )
    }
}

private struct MockTool: LLMToolSchemaProviding {
    let name: String
    let toolDescription: String
    let inputSchema: [String: Any]
}
