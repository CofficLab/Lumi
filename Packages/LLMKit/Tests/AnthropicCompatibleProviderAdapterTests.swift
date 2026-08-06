import XCTest
@testable import LLMKit

final class AnthropicCompatibleProviderAdapterTests: XCTestCase {
    func testBuildRequestSetsMethodAuthContentTypeAndHeaders() throws {
        let adapter = AnthropicCompatibleProviderAdapter(
            configuration: .init(
                baseURL: "https://api.anthropic.com/v1/messages",
                additionalHeaders: ["X-Custom": "value"],
                apiVersion: "2023-06-01"
            )
        )

        let request = adapter.buildRequest(
            url: try XCTUnwrap(URL(string: adapter.configuration.baseURL)),
            apiKey: "sk-ant-123"
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-123")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom"), "value")
    }

    func testBuildRequestBodyIncludesSystemFieldAndMaxTokens() throws {
        let adapter = makeAdapter()
        let messages = [
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi"),
        ]

        let body = try adapter.buildRequestBody(
            messages: messages,
            model: "claude-sonnet-4-20250514",
            tools: nil,
            systemPrompt: "Be helpful"
        )

        XCTAssertEqual(body["model"] as? String, "claude-sonnet-4-20250514")
        XCTAssertEqual(body["system"] as? String, "Be helpful")
        XCTAssertEqual(body["max_tokens"] as? Int, 8192)
        XCTAssertNil(body["stream"])

        let encodedMessages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(encodedMessages.count, 2)
        XCTAssertEqual(encodedMessages[0]["role"] as? String, "user")
        XCTAssertEqual(encodedMessages[0]["content"] as? String, "Hello")
        XCTAssertEqual(encodedMessages[1]["role"] as? String, "assistant")
        XCTAssertEqual(encodedMessages[1]["content"] as? String, "Hi")
    }

    func testBuildRequestBodyMergesSystemMessages() throws {
        let adapter = makeAdapter()

        let body = try adapter.buildRequestBody(
            messages: [
                ChatMessage(role: .system, content: "System 1"),
                ChatMessage(role: .user, content: "Hello"),
            ],
            model: "claude-sonnet-4-20250514",
            tools: nil,
            systemPrompt: "Default"
        )

        XCTAssertEqual(body["system"] as? String, "System 1")

        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["role"] as? String, "user")
    }

    func testBuildRequestBodyFormatsTools() throws {
        let adapter = makeAdapter()
        let tool = MockAnthropicTool(
            name: "read_file",
            toolDescription: "Read a file",
            inputSchema: [
                "type": "object",
                "properties": ["path": ["type": "string"]],
            ]
        )

        let body = try adapter.buildRequestBody(
            messages: [ChatMessage(role: .user, content: "Read")],
            model: "claude-sonnet-4-20250514",
            tools: [tool],
            systemPrompt: ""
        )

        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.count, 1)
        XCTAssertNil(tools[0]["type"]) // Anthropic 格式没有 "type": "function"
        XCTAssertEqual(tools[0]["name"] as? String, "read_file")
        XCTAssertEqual(tools[0]["description"] as? String, "Read a file")

        let parameters = try XCTUnwrap(tools[0]["input_schema"] as? [String: Any])
        XCTAssertEqual(parameters["type"] as? String, "object")
    }

    func testFormatToolSanitizesDottedName() throws {
        // Kimi 等 Anthropic 兼容端点拒绝带点号的函数名(400 invalid_request_error)，
        // app-store-connect.* 这类 MCP 工具名必须转义
        let adapter = makeAdapter()
        let tool = MockAnthropicTool(
            name: "app-store-connect.list-apps",
            toolDescription: "List App Store Connect apps",
            inputSchema: ["type": "object"]
        )

        let body = try adapter.buildRequestBody(
            messages: [ChatMessage(role: .user, content: "List apps")],
            model: "k3",
            tools: [tool],
            systemPrompt: ""
        )

        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
        XCTAssertEqual(tools[0]["name"] as? String, "app-store-connect_list-apps")
    }

    func testTransformMessageSanitizesToolUseNameOnReplay() {
        // 历史 assistant 消息回传 tool_use 时同样要转义，否则下一轮请求仍会被拒绝
        let adapter = makeAdapter()
        let message = ChatMessage(
            role: .assistant,
            content: "Calling tool",
            toolCalls: [
                ToolCall(
                    id: "call_1",
                    name: "app-store-connect.list-apps",
                    arguments: "{}"
                ),
            ]
        )

        let encoded = adapter.transformMessage(message)
        let content = try! XCTUnwrap(encoded["content"] as? [[String: Any]])
        let toolUse = try! XCTUnwrap(content.first { ($0["type"] as? String) == "tool_use" })

        XCTAssertEqual(toolUse["name"] as? String, "app-store-connect_list-apps")
    }

    func testBuildStreamingRequestBodySetsStreamTrue() throws {
        let adapter = makeAdapter()

        let body = try adapter.buildStreamingRequestBody(
            messages: [ChatMessage(role: .user, content: "Hello")],
            model: "claude-sonnet-4-20250514",
            tools: nil,
            systemPrompt: ""
        )

        XCTAssertEqual(body["stream"] as? Bool, true)
    }

    func testBuildRequestBodyExcludesNonSendableRolesAfterPrepare() throws {
        let adapter = makeAdapter()
        let messages = LLMMessagePreparer.prepare([
            ChatMessage(role: .user, content: "1"),
            ChatMessage(role: .assistant, content: "Hi"),
            ChatMessage(role: .error, content: "failed"),
            ChatMessage(role: .status, content: "__lumi_turn_completed__"),
            ChatMessage(role: .user, content: "Second"),
        ])

        let body = try adapter.buildRequestBody(
            messages: messages,
            model: "qwen3.7-max",
            tools: nil,
            systemPrompt: "Be helpful"
        )

        let encodedMessages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(encodedMessages.count, 3)
        XCTAssertEqual(encodedMessages[0]["role"] as? String, "user")
        XCTAssertEqual(encodedMessages[1]["role"] as? String, "assistant")
        XCTAssertEqual(encodedMessages[2]["role"] as? String, "user")
    }

    func testTransformUserMessage() {
        let adapter = makeAdapter()

        let message = adapter.transformMessage(
            ChatMessage(role: .user, content: "Hello")
        )

        XCTAssertEqual(message["role"] as? String, "user")
        XCTAssertEqual(message["content"] as? String, "Hello")
    }

    func testTransformToolResultMessage() {
        let adapter = makeAdapter()

        let message = adapter.transformMessage(
            ChatMessage(role: .tool, content: "result", toolCallID: "call_123")
        )

        XCTAssertEqual(message["role"] as? String, "user")
        let content = message["content"] as? [[String: Any]]
        XCTAssertEqual(content?.count, 1)
        XCTAssertEqual(content?[0]["type"] as? String, "tool_result")
        XCTAssertEqual(content?[0]["tool_use_id"] as? String, "call_123")
        XCTAssertEqual(content?[0]["content"] as? String, "result")
    }

    func testTransformAssistantMessageWithToolCalls() throws {
        let adapter = makeAdapter()

        let message = adapter.transformMessage(
            ChatMessage(
                role: .assistant,
                content: "Thinking...",
                toolCalls: [
                    ToolCall(id: "call_123", name: "read_file", arguments: #"{"path":"README.md"}"#),
                ]
            )
        )

        XCTAssertEqual(message["role"] as? String, "assistant")
        let content = try XCTUnwrap(message["content"] as? [[String: Any]])
        XCTAssertEqual(content.count, 2)
        XCTAssertEqual(content[0]["type"] as? String, "text")
        XCTAssertEqual(content[0]["text"] as? String, "Thinking...")
        XCTAssertEqual(content[1]["type"] as? String, "tool_use")
        XCTAssertEqual(content[1]["id"] as? String, "call_123")
        XCTAssertEqual(content[1]["name"] as? String, "read_file")
    }

    func testBuildRequestBodyCombinesConsecutiveToolResults() throws {
        let body = try makeAdapter().buildRequestBody(
            messages: [
                ChatMessage(role: .user, content: "Run both"),
                ChatMessage(
                    role: .assistant,
                    content: "",
                    toolCalls: [
                        ToolCall(id: "call_1", name: "first", arguments: "{}"),
                        ToolCall(id: "call_2", name: "second", arguments: "{}"),
                    ]
                ),
                ChatMessage(role: .tool, content: "one", toolCallID: "call_1"),
                ChatMessage(role: .tool, content: "two", toolCallID: "call_2"),
            ],
            model: "MiniMax-M2.7",
            tools: nil,
            systemPrompt: ""
        )

        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[2]["role"] as? String, "user")
        let results = try XCTUnwrap(messages[2]["content"] as? [[String: Any]])
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.map { $0["tool_use_id"] as? String }, ["call_1", "call_2"])
    }

    func testBuildRequestBodyDropsUnresolvedTrailingToolUse() throws {
        let body = try makeAdapter().buildRequestBody(
            messages: [
                ChatMessage(role: .user, content: "Continue"),
                ChatMessage(
                    role: .assistant,
                    content: "I will continue.",
                    toolCalls: [ToolCall(id: "call_pending", name: "commit", arguments: "{}")]
                ),
            ],
            model: "MiniMax-M2.7",
            tools: nil,
            systemPrompt: ""
        )

        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 3)
        let assistantContent = try XCTUnwrap(messages[1]["content"] as? [[String: Any]])
        XCTAssertEqual(assistantContent[0]["type"] as? String, "text")
        XCTAssertEqual(assistantContent[1]["type"] as? String, "tool_use")
        let resultContent = try XCTUnwrap(messages[2]["content"] as? [[String: Any]])
        XCTAssertEqual(resultContent[0]["tool_use_id"] as? String, "call_pending")
        XCTAssertEqual(resultContent[0]["is_error"] as? Bool, true)
    }

    func testTransformAssistantMessageIncludesReasoningHistory() throws {
        let message = makeAdapter().transformMessage(
            ChatMessage(role: .assistant, content: "Answer", reasoningContent: "Think")
        )

        let content = try XCTUnwrap(message["content"] as? [[String: Any]])
        XCTAssertEqual(content.map { $0["type"] as? String }, ["thinking", "text"])
        XCTAssertEqual(content[0]["thinking"] as? String, "Think")
    }

    func testParseResponseReturnsContentAndToolCalls() throws {
        let adapter = makeAdapter()
        let data = Data(
            """
            {
              "content": [
                {"type": "text", "text": "Done"},
                {
                  "type": "tool_use",
                  "id": "call_123",
                  "name": "read_file",
                  "input": {"path": "README.md"}
                }
              ]
            }
            """.utf8
        )

        let result = try adapter.parseResponse(data: data)

        XCTAssertEqual(result.content, "Done")
        XCTAssertEqual(result.toolCalls?.count, 1)
        XCTAssertEqual(result.toolCalls?.first?.id, "call_123")
        XCTAssertEqual(result.toolCalls?.first?.name, "read_file")
    }

    func testParseResponseThrowsAPIError() {
        let adapter = makeAdapter()
        let data = Data(#"{"error":{"message":"Invalid API key"}}"#.utf8)

        XCTAssertThrowsError(try adapter.parseResponse(data: data)) { error in
            XCTAssertEqual(
                error as? AnthropicCompatibleProviderError,
                .apiError(message: "Invalid API key")
            )
        }
    }

    func testParseStreamTextDelta() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Hello\"}}\n\n".utf8)
        )

        XCTAssertEqual(chunk?.content, "Hello")
        XCTAssertEqual(chunk?.eventType, .textDelta)
    }

    func testParseStreamTextDeltaWithCRLFLineEndings() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("event: content_block_delta\r\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Hello\"}}\r\n\r\n".utf8)
        )

        XCTAssertEqual(chunk?.content, "Hello")
        XCTAssertEqual(chunk?.eventType, .textDelta)
    }

    func testParseStreamMessageStart() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":50,\"cache_read_input_tokens\":30,\"cache_creation_input_tokens\":20}}}\n\n".utf8)
        )

        XCTAssertEqual(chunk?.eventType, .messageStart)
        XCTAssertEqual(chunk?.inputTokens, 50)
        XCTAssertEqual(chunk?.cachedInputTokens, 30)
        XCTAssertEqual(chunk?.cacheWriteInputTokens, 20)
        // Anthropic 官方语义:input_tokens(50) 已含 read(30)+write(20),直接作分母
        XCTAssertEqual(chunk?.cacheTotalInputTokens, 50)
    }

    func testParseStreamMessageStartDeepSeekSemantics() throws {
        // DeepSeek 兼容层实测语义:input_tokens 是「未命中」部分,总输入 = input + read + write
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":68,\"cache_read_input_tokens\":512}}}\n\n".utf8)
        )
        XCTAssertEqual(chunk?.eventType, .messageStart)
        XCTAssertEqual(chunk?.inputTokens, 68)
        XCTAssertEqual(chunk?.cachedInputTokens, 512)
        XCTAssertEqual(chunk?.cacheTotalInputTokens, 580)
    }

    func testParseStreamMessageStop() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n".utf8)
        )

        XCTAssertEqual(chunk?.isDone, true)
        XCTAssertEqual(chunk?.eventType, .messageStop)
    }

    func testParseStreamToolUseStart() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":1,\"content_block\":{\"type\":\"tool_use\",\"id\":\"call_123\",\"name\":\"read_file\"}}\n\n".utf8)
        )

        XCTAssertEqual(chunk?.eventType, .contentBlockStart)
        XCTAssertEqual(chunk?.toolCalls?.count, 1)
        XCTAssertEqual(chunk?.toolCalls?.first?.id, "call_123")
        XCTAssertEqual(chunk?.toolCalls?.first?.name, "read_file")
    }

    func testParseStreamToolArgumentsDelta() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"{\\\"path\\\":\"}}\n\n".utf8)
        )

        XCTAssertEqual(chunk?.eventType, .inputJsonDelta)
        XCTAssertEqual(chunk?.partialJson, "{\"path\":")
    }

    func testParseStreamPing() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("event: ping\ndata: {\"type\":\"ping\"}\n\n".utf8)
        )

        XCTAssertEqual(chunk?.eventType, .ping)
    }

    func testParseStreamError() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("event: error\ndata: {\"type\":\"error\",\"error\":{\"message\":\"Rate limited\"}}\n\n".utf8)
        )

        XCTAssertEqual(chunk?.error, "Rate limited")
    }

    func testParseStreamThinkingDelta() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"thinking_delta\",\"thinking\":\"Let me think...\"}}\n\n".utf8)
        )

        XCTAssertEqual(chunk?.eventType, .thinkingDelta)
        XCTAssertEqual(chunk?.content, "Let me think...")
    }

    func testParseStreamChunkWithDoneMarker() throws {
        // ZhiPu 发送 data: [DONE] 作为流结束标志，不应崩溃
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("data: [DONE]\n\n".utf8)
        )
        XCTAssertNotNil(chunk, "data: [DONE] should return a valid chunk, not throw")
        XCTAssertEqual(chunk?.isDone, true)
        XCTAssertEqual(chunk?.eventType, .messageStop)
    }

    func testParseStreamChunkWithDoneMarkerAndEvent() throws {
        // 带 event: prefix 的 [DONE] 也不应崩溃
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("event: done\ndata: [DONE]\n\n".utf8)
        )
        XCTAssertNotNil(chunk, "event: done + data: [DONE] should not throw")
        XCTAssertEqual(chunk?.isDone, true)
        XCTAssertEqual(chunk?.eventType, .messageStop)
    }

    func testParseStreamReturnsNilForNonDataEvent() throws {
        let chunk = try makeAdapter().parseStreamChunk(
            data: Data("event: ping\n\n".utf8)
        )

        XCTAssertNil(chunk)
    }

    private func makeAdapter() -> AnthropicCompatibleProviderAdapter {
        AnthropicCompatibleProviderAdapter(
            configuration: .init(baseURL: "https://api.anthropic.com/v1/messages")
        )
    }
}

private struct MockAnthropicTool: LLMToolSchemaProviding {
    let name: String
    let toolDescription: String
    let inputSchema: [String: Any]
}
