import Foundation
import LumiCoreKit
import Testing
@testable import ToolCallLoopDetectionPlugin

@Suite("ToolCallLoopDetector")
struct ToolCallLoopDetectorTests {
    private let conversationId = UUID()

    @Test("does not detect loop below threshold")
    func belowThreshold() {
        let messages = repeatedAssistantToolMessages(count: 2, name: "read_file", arguments: #"{"path":"a.txt"}"#)
        #expect(ToolCallLoopDetector.detect(in: messages) == nil)
    }

    @Test("detects repeated identical tool calls")
    func detectsRepeatedCalls() {
        let messages = repeatedAssistantToolMessages(count: 3, name: "read_file", arguments: #"{"path":"a.txt"}"#)
        let pattern = ToolCallLoopDetector.detect(in: messages)
        #expect(pattern?.toolName == "read_file")
        #expect(pattern?.count == 3)
        #expect(pattern?.threshold == 3)
    }

    @Test("does not count different arguments as the same loop")
    func differentArgumentsAreDistinct() {
        var messages: [AgentChatMessage] = []
        for index in 0 ..< 3 {
            messages.append(
                assistantToolMessage(
                    name: "read_file",
                    arguments: "{\"path\":\"file\(index).txt\"}"
                )
            )
        }
        #expect(ToolCallLoopDetector.detect(in: messages) == nil)
    }

    private func repeatedAssistantToolMessages(
        count: Int,
        name: String,
        arguments: String
    ) -> [AgentChatMessage] {
        (0 ..< count).map { _ in
            assistantToolMessage(name: name, arguments: arguments)
        }
    }

    private func assistantToolMessage(name: String, arguments: String) -> AgentChatMessage {
        var toolCall = ToolCall(id: UUID().uuidString, name: name, arguments: arguments)
        toolCall.result = ToolCallResult(content: "ok")
        return AgentChatMessage(
            role: .assistant,
            conversationId: conversationId,
            content: "",
            toolCalls: [toolCall]
        )
    }
}
