import Foundation
import LumiKernel
import Testing
@testable import LLMProviderDeepSeekPlugin

/// 用 `LumiAgentTool` 协议构造请求体所需的最小 mock。
///
/// 仅实现 builder 关心的字段：`name` / `toolDescription` / `inputSchema`。
/// 不需要真实可执行的 `execute(...)`，因为 builder 不会调用它。
private final class StubTool: LumiAgentTool, @unchecked Sendable {
    let stubName: String
    let stubDescription: String
    let stubSchema: LumiJSONValue

    init(name: String, description: String = "", schema: LumiJSONValue = .object([:])) {
        self.stubName = name
        self.stubDescription = description
        self.stubSchema = schema
    }

    static var info: LumiAgentToolInfo {
        // 实际不会被 builder 用到；提供一个静态 info 满足协议。
        .init(id: "stub", displayName: "stub", description: "")
    }
    var name: String { stubName }
    var toolDescription: String { stubDescription }
    var inputSchema: LumiJSONValue { stubSchema }
    var tags: Set<LumiToolTag> { [] }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String { "" }
    func executeResult(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> LumiToolExecutionResult {
        LumiToolExecutionResult(content: "")
    }
}

@Suite("AnthropicRequestBuilder")
struct AnthropicRequestBuilderTests {

    private func makeRequest(
        messages: [LumiChatMessage],
        tools: [any LumiAgentTool] = [],
        reasoning: LumiReasoningEffort? = nil
    ) -> LumiLLMRequest {
        LumiLLMRequest(
            messages: messages,
            model: "deepseek-v4-pro",
            tools: tools,
            imageAttachments: [],
            fileAttachments: [],
            generationOptions: LumiLLMGenerationOptions(reasoningEffort: reasoning)
        )
    }

    @Test("system 消息聚合到顶层 system 字段，不进 messages")
    func systemAggregatedToTopLevel() throws {
        let conversation = UUID()
        let request = makeRequest(messages: [
            LumiChatMessage(conversationID: conversation, role: .system, content: "你是助手 A"),
            LumiChatMessage(conversationID: conversation, role: .system, content: "不要撒谎"),
            LumiChatMessage(conversationID: conversation, role: .user, content: "你好"),
        ])
        let body = AnthropicRequestBuilder.body(for: request)
        let system = try #require(body["system"])
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        // 多条 system 应当用数组形式保留分段
        if let array = system as? [[String: Any]] {
            #expect(array.count == 2)
        } else {
            Issue.record("多条 system 应序列化为数组，实际为：\(system)")
        }
    }

    @Test("单条 system 序列化为字符串而非数组")
    func singleSystemSerializedAsString() {
        let conversation = UUID()
        let request = makeRequest(messages: [
            LumiChatMessage(conversationID: conversation, role: .system, content: "你是助手"),
            LumiChatMessage(conversationID: conversation, role: .user, content: "hi"),
        ])
        let body = AnthropicRequestBuilder.body(for: request)
        #expect(body["system"] is String)
    }

    @Test("user 消息生成 content blocks 数组")
    func userMessageContentBlocks() {
        let conversation = UUID()
        let request = makeRequest(messages: [
            LumiChatMessage(conversationID: conversation, role: .user, content: "你好")
        ])
        let body = AnthropicRequestBuilder.body(for: request)
        guard let messages = body["messages"] as? [[String: Any]],
              let first = messages.first,
              let content = first["content"] as? [[String: Any]]
        else {
            Issue.record("user 消息 content 应为 blocks 数组")
            return
        }
        #expect(first["role"] as? String == "user")
        #expect(content.first?["type"] as? String == "text")
        #expect(content.first?["text"] as? String == "你好")
    }

    @Test("assistant 的 toolCalls 序列化为 tool_use blocks")
    func assistantToolCallsToToolUseBlocks() {
        let conversation = UUID()
        let call = LumiToolCall(id: "call_123", name: "search", arguments: "{\"q\":\"swift\"}")
        let request = makeRequest(messages: [
            LumiChatMessage(
                conversationID: conversation,
                role: .assistant,
                content: "让我查一下",
                toolCalls: [call]
            )
        ])
        let body = AnthropicRequestBuilder.body(for: request)
        guard let messages = body["messages"] as? [[String: Any]],
              let first = messages.first,
              let content = first["content"] as? [[String: Any]]
        else {
            Issue.record("assistant content 应为 blocks 数组")
            return
        }
        // 期望至少两个 block：text + tool_use
        #expect(content.count == 2)
        let types = content.compactMap { $0["type"] as? String }
        #expect(types == ["text", "tool_use"])
        let toolUse = content[1]
        #expect(toolUse["id"] as? String == "call_123")
        #expect(toolUse["name"] as? String == "search")
        guard let input = toolUse["input"] as? [String: Any] else {
            Issue.record("tool_use input 必须是对象")
            return
        }
        #expect(input["q"] as? String == "swift")
    }

    @Test("tool 角色消息序列化为 user + tool_result block")
    func toolResponseToToolResultBlock() {
        let conversation = UUID()
        let request = makeRequest(messages: [
            LumiChatMessage(
                conversationID: conversation,
                role: .tool,
                content: "搜索结果: ...",
                toolCallID: "call_123"
            )
        ])
        let body = AnthropicRequestBuilder.body(for: request)
        guard let messages = body["messages"] as? [[String: Any]],
              let first = messages.first
        else {
            Issue.record("tool 响应应被序列化")
            return
        }
        // tool 响应在 Anthropic 是 user message 的 tool_result block
        #expect(first["role"] as? String == "user")
        guard let content = first["content"] as? [[String: Any]] else {
            Issue.record("tool 响应 content 应为 blocks 数组")
            return
        }
        #expect(content.first?["type"] as? String == "tool_result")
        #expect(content.first?["tool_use_id"] as? String == "call_123")
        #expect(content.first?["content"] as? String == "搜索结果: ...")
    }

    @Test("tools 字段映射为 Anthropic 格式（无 type 包装）")
    func toolsFieldShape() {
        let conversation = UUID()
        let schema: LumiJSONValue = .object([
            "type": .string("object"),
            "properties": .object([
                "q": .object(["type": .string("string")])
            ])
        ])
        let tool = StubTool(name: "search", description: "搜索工具", schema: schema)
        let request = makeRequest(
            messages: [LumiChatMessage(conversationID: conversation, role: .user, content: "hi")],
            tools: [tool]
        )
        let body = AnthropicRequestBuilder.body(for: request)
        guard let tools = body["tools"] as? [[String: Any]],
              let first = tools.first
        else {
            Issue.record("tools 应为数组")
            return
        }
        #expect(first["name"] as? String == "search")
        #expect(first["description"] as? String == "搜索工具")
        #expect(first["input_schema"] != nil)
        #expect(first["type"] == nil, "Anthropic tools 不应有 type:function 包装")
    }

    @Test("thinking 在非 automatic 时启用，自动时不启用")
    func thinkingEnabledByReasoningEffort() {
        let conversation = UUID()
        let base = LumiChatMessage(conversationID: conversation, role: .user, content: "hi")
        let auto = AnthropicRequestBuilder.body(for: makeRequest(messages: [base], reasoning: .automatic))
        #expect(auto["thinking"] == nil, "automatic 不应启用 thinking")

        let high = AnthropicRequestBuilder.body(for: makeRequest(messages: [base], reasoning: .high))
        guard let thinking = high["thinking"] as? [String: Any] else {
            Issue.record("high 应启用 thinking")
            return
        }
        #expect(thinking["type"] as? String == "enabled")
        #expect(thinking["budget_tokens"] as? Int == 8192)
    }

    @Test("max_tokens 与 stream 是必填顶层字段")
    func topLevelRequiredFields() {
        let conversation = UUID()
        let request = makeRequest(messages: [
            LumiChatMessage(conversationID: conversation, role: .user, content: "hi")
        ])
        let body = AnthropicRequestBuilder.body(for: request)
        #expect(body["max_tokens"] as? Int == AnthropicRequestBuilder.defaultMaxTokens)
        #expect(body["stream"] as? Bool == true)
        #expect(body["model"] as? String == "deepseek-v4-pro")
    }

    @Test("assistant 的 reasoningContent 回传为 thinking block(缓存前缀单元可复用)")
    func assistantReasoningToThinkingBlock() {
        let conversation = UUID()
        let request = makeRequest(messages: [
            LumiChatMessage(
                conversationID: conversation,
                role: .assistant,
                content: "最终回答",
                reasoningContent: "让我先思考一下"
            )
        ])
        let body = AnthropicRequestBuilder.body(for: request)
        guard let messages = body["messages"] as? [[String: Any]],
              let first = messages.first,
              let content = first["content"] as? [[String: Any]]
        else {
            Issue.record("assistant content 应为 blocks 数组")
            return
        }
        // thinking block 在前,text block 在后
        #expect(content.count == 2)
        let types = content.compactMap { $0["type"] as? String }
        #expect(types == ["thinking", "text"])
        #expect(content[0]["thinking"] as? String == "让我先思考一下")
        #expect(content[1]["text"] as? String == "最终回答")
    }

    @Test("assistant 仅含 reasoningContent 时仍输出 thinking block")
    func assistantOnlyReasoningStillHasBlock() {
        let conversation = UUID()
        let request = makeRequest(messages: [
            LumiChatMessage(
                conversationID: conversation,
                role: .assistant,
                content: "",
                reasoningContent: "思考过程"
            )
        ])
        let body = AnthropicRequestBuilder.body(for: request)
        guard let messages = body["messages"] as? [[String: Any]],
              let first = messages.first,
              let content = first["content"] as? [[String: Any]]
        else {
            Issue.record("assistant content 应为 blocks 数组")
            return
        }
        #expect(content.count == 1)
        #expect(content.first?["type"] as? String == "thinking")
    }
}