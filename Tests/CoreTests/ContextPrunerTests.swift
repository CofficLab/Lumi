#if canImport(XCTest)
import XCTest
import AgentToolKit
@testable import Lumi

final class ContextPrunerTests: XCTestCase {
    func testPruneKeepsUserContinuationWhenOnlyOrphanToolRemains() {
        let conversationId = UUID()
        let messages = [
            ChatMessage(role: .user, conversationId: conversationId, content: "Run it"),
            ChatMessage(
                role: .assistant,
                conversationId: conversationId,
                content: "",
                toolCalls: [
                    ToolCall(id: "call_1", name: "shell", arguments: "{}")
                ]
            ),
            ChatMessage(role: .tool, conversationId: conversationId, content: "done", toolCallID: "call_1")
        ]

        let result = ContextPruner.prune(
            messages,
            config: ContextPruner.Configuration(
                maxMessages: 1,
                tokenUsageThreshold: 0.8,
                tighteningFactor: 0.6,
                summaryPlaceholder: "summary"
            )
        )

        XCTAssertEqual(result.messages.map(\.role), [.system, .user])
        XCTAssertEqual(result.messages.last?.conversationId, conversationId)
        XCTAssertFalse(result.messages.last?.content.isEmpty ?? true)
    }

    func testPruneKeepsUserContinuationWhenWindowKeepsNothing() {
        let conversationId = UUID()
        let messages = [
            ChatMessage(role: .user, conversationId: conversationId, content: "Hello")
        ]

        let result = ContextPruner.prune(
            messages,
            config: ContextPruner.Configuration(
                maxMessages: 0,
                tokenUsageThreshold: 0.8,
                tighteningFactor: 0.6,
                summaryPlaceholder: "summary"
            )
        )

        XCTAssertEqual(result.messages.map(\.role), [.system, .user])
        XCTAssertEqual(result.messages.last?.conversationId, conversationId)
    }
}
#endif
