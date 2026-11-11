import Foundation
import KitLLM
import Testing
@testable import KitLLM

/// 部分完成的多工具历史必须在出站时被修复。
///
/// ## 为什么要有这条测试
///
/// 一次 assistant 回合可以请求多个工具。自动执行的 A 先完成、审批中的 B
/// 一直挂着时按下停止，B 没有独立的结果消息。
///
/// 发送层此前看到「至少有一个结果」就保留**全部** tool_call 声明，未配对
/// 的 B 让上游直接拒绝请求——用户无法继续对话。已完成的结果必须保留。
@Suite("OpenAI 多工具历史的未配对修复")
struct OpenAIUnpairedToolCallRepairTests {

    private func adapter() -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(
                baseURL: "https://example.invalid/v1/chat/completions"
            )
        )
    }

    @Test("未配对的 tool_call 被移出请求，已完成的保留")
    func unpairedToolCallIsRemovedFromRequest() throws {
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
            model: "gpt-4o",
            tools: nil,
            systemPrompt: ""
        )

        let conversation = body["messages"] as? [[String: Any]]
        let assistant = try #require(
            conversation?.first { ($0["role"] as? String) == "assistant" },
            "请求里应有 assistant 消息"
        )
        let toolCalls = assistant["tool_calls"] as? [[String: Any]]
        let callIDs = Set(toolCalls?.compactMap { $0["id"] as? String } ?? [])

        #expect(
            callIDs == ["call_a"],
            "只有已完成的调用应保留，实际 \(callIDs)"
        )
        #expect(
            !callIDs.contains("call_b"),
            "未配对的调用必须被移出请求"
        )
    }

    @Test("全部配对时 tool_calls 完整保留")
    func fullyPairedToolCallsAreKept() throws {
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
            LLMMessage(role: .tool, content: "done a", toolCallID: "call_a"),
            LLMMessage(role: .tool, content: "done b", toolCallID: "call_b"),
        ]

        let body = try adapter().buildRequestBody(
            messages: messages,
            model: "gpt-4o",
            tools: nil,
            systemPrompt: ""
        )

        let conversation = body["messages"] as? [[String: Any]]
        let assistant = try #require(
            conversation?.first { ($0["role"] as? String) == "assistant" },
            "请求里应有 assistant 消息"
        )
        let toolCalls = assistant["tool_calls"] as? [[String: Any]]
        let callIDs = Set(toolCalls?.compactMap { $0["id"] as? String } ?? [])

        #expect(callIDs == ["call_a", "call_b"], "全部配对时不应移除任何调用")
    }

    @Test("已完成的 tool 结果仍然发送")
    func completedToolResultIsStillSent() throws {
        let messages = [
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [
                    LLMToolCall(id: "call_a", name: "tool_a", arguments: "{}"),
                    LLMToolCall(id: "call_b", name: "tool_b", arguments: "{}"),
                ]
            ),
            LLMMessage(role: .tool, content: "done", toolCallID: "call_a"),
        ]

        let body = try adapter().buildRequestBody(
            messages: messages,
            model: "gpt-4o",
            tools: nil,
            systemPrompt: ""
        )

        let conversation = body["messages"] as? [[String: Any]]
        let toolMessage = try #require(
            conversation?.first { ($0["role"] as? String) == "tool" },
            "已完成的 tool 结果应保留"
        )
        #expect(toolMessage["content"] as? String == "done")
    }
}
