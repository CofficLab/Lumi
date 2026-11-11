import Foundation
import KitLLM
import Testing
@testable import KitLLM

/// Anthropic 的部分完成多工具历史必须被修复。
///
/// ## 为什么要有这条测试
///
/// Anthropic 要求同一次 assistant 回合里的每个 `tool_use` 都有对应的
/// `tool_result`。适配器此前只在 assistant 是**最后一条**消息时补错误
/// 结果——后面还有 user 消息（用户又发了一句话）时就不补了。
///
/// 结果是下一轮请求带着未配对的 `tool_use`，被上游拒绝，用户无法继续
/// 对话。
@Suite("Anthropic 多工具历史的未配对修复")
struct AnthropicUnpairedToolCallRepairTests {

    private func adapter() -> AnthropicCompatibleProviderAdapter {
        AnthropicCompatibleProviderAdapter(
            configuration: AnthropicCompatibleProviderConfiguration(
                baseURL: "https://example.invalid/v1/messages"
            )
        )
    }

    /// 请求体里的 tool_result 块。
    private func toolResultIDs(_ body: [String: Any]) -> [String] {
        let messages = body["messages"] as? [[String: Any]] ?? []
        var ids: [String] = []
        for message in messages {
            guard let content = message["content"] as? [[String: Any]] else { continue }
            for block in content where block["type"] as? String == "tool_result" {
                if let id = block["tool_use_id"] as? String {
                    ids.append(id)
                }
            }
        }
        return ids
    }

    @Test("assistant 之后还有 user 消息时，未配对的调用被补上错误结果")
    func unpairedToolUseIsRepairedWhenFollowedByUserMessage() throws {
        let messages = [
            LLMMessage(role: .user, content: "do it"),
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [
                    LLMToolCall(id: "call_a", name: "tool_a", arguments: "{}"),
                    LLMToolCall(id: "call_b", name: "tool_b", arguments: "{}"),
                ]
            ),
            LLMMessage(role: .tool, content: "done", toolCallID: "call_a"),
            LLMMessage(role: .user, content: "continue"),
        ]

        let body = try adapter().buildRequestBody(
            messages: messages,
            model: "claude-sonnet-4",
            tools: nil,
            systemPrompt: ""
        )

        let resultIDs = toolResultIDs(body)
        #expect(
            resultIDs.contains("call_b"),
            "未配对的 tool_use 必须补上错误结果，实际 \(resultIDs)"
        )
    }

    @Test("已完成的调用不被重复补结果")
    func completedToolUseIsNotDuplicated() throws {
        let messages = [
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [
                    LLMToolCall(id: "call_a", name: "tool_a", arguments: "{}"),
                    LLMToolCall(id: "call_b", name: "tool_b", arguments: "{}"),
                ]
            ),
            LLMMessage(role: .tool, content: "done a", toolCallID: "call_a"),
            LLMMessage(role: .tool, content: "done b", toolCallID: "call_b"),
        ]

        let body = try adapter().buildRequestBody(
            messages: messages,
            model: "claude-sonnet-4",
            tools: nil,
            systemPrompt: ""
        )

        // 每个已完成的调用只应出现一次结果（真实结果，不是补的错误结果）。
        let resultIDs = toolResultIDs(body)
        #expect(
            resultIDs.filter { $0 == "call_a" }.count == 1,
            "已完成的调用不应重复补结果，实际 \(resultIDs)"
        )
        #expect(
            resultIDs.filter { $0 == "call_b" }.count == 1,
            "已完成的调用不应重复补结果，实际 \(resultIDs)"
        )
    }

    @Test("assistant 是最后一条消息时仍然修复")
    func trailingAssistantIsStillRepaired() throws {
        let messages = [
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [LLMToolCall(id: "call_a", name: "tool_a", arguments: "{}")]
            ),
        ]

        let body = try adapter().buildRequestBody(
            messages: messages,
            model: "claude-sonnet-4",
            tools: nil,
            systemPrompt: ""
        )

        #expect(
            toolResultIDs(body).contains("call_a"),
            "尾部 assistant 的未配对调用仍须修复"
        )
    }
}
