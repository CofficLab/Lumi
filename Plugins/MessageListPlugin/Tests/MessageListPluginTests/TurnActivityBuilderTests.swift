import Foundation
import KernelLumi
import Testing
@testable import MessageListPlugin

@Suite("TurnActivityBuilder")
struct TurnActivityBuilderTests {
    @Test("sorts calls and derives progress metrics")
    func buildsActivitySnapshot() {
        let conversationID = UUID()
        let turnID = UUID()
        let later = Date(timeIntervalSince1970: 20)
        let earlier = Date(timeIntervalSince1970: 10)
        let first = makeRecord(
            id: "first",
            turnID: turnID,
            conversationID: conversationID,
            startedAt: later,
            completedAt: later,
            duration: 0.2,
            resultIsError: true
        )
        let second = makeRecord(
            id: "second",
            turnID: turnID,
            conversationID: conversationID,
            startedAt: earlier,
            completedAt: earlier,
            duration: 0.3,
            resultIsError: false
        )

        let activity = TurnActivityBuilder.build(
            turnID: turnID,
            conversationID: conversationID,
            state: .completed,
            toolCalls: [first, second]
        )

        #expect(activity.id == turnID)
        #expect(activity.toolCalls.map(\.id) == ["second", "first"])
        #expect(activity.totalCount == 2)
        #expect(activity.completedCount == 2)
        #expect(activity.failedCount == 1)
        #expect(activity.totalDuration == 0.5)
    }

    private func makeRecord(
        id: String,
        turnID: UUID,
        conversationID: UUID,
        startedAt: Date,
        completedAt: Date?,
        duration: TimeInterval?,
        resultIsError: Bool
    ) -> LumiToolCallRecord {
        LumiToolCallRecord(
            id: id,
            turnID: turnID,
            toolName: "tool",
            toolDisplayName: id,
            conversationID: conversationID,
            createdAt: startedAt,
            startedAt: startedAt,
            completedAt: completedAt,
            duration: duration,
            argumentsJSON: "{}",
            resultContent: "",
            resultIsError: resultIsError,
            riskLevel: "low",
            turnControl: nil
        )
    }
}
