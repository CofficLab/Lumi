import Foundation
import ProviderMessage
import Testing
@testable import GoalTaskPlugin

@Suite("Goal Task Timeline")
struct GoalTaskTimelineTests {
    @Test("continuation message is a timeline event with progress metadata")
    func continuationMessage() {
        let conversationID = UUID()
        let turnID = UUID()
        let message = GoalTaskTimeline.continuationMessage(
            conversationID: conversationID,
            turnID: turnID,
            attempt: 2,
            maxAttempts: 5,
            goalTitles: ["发布 iOS 版本"]
        )

        #expect(message.role == .system)
        #expect(message.conversationID == conversationID)
        #expect(message.turnID == turnID)
        #expect(message.content == "Goal 自动继续（2/5）")
        #expect(MessageTimelineEvent.isGoalTaskContinuation(message))
        #expect(MessageTimelineEvent.isTimelineEvent(message))
        #expect(message.metadata[MessageTimelineEvent.goalTaskContinuationAttemptKey] == "2")
        #expect(message.metadata[MessageTimelineEvent.goalTaskContinuationGoalTitlesKey] == "发布 iOS 版本")
    }

    @Test("limit message explains why automatic continuation stopped")
    func limitReachedMessage() {
        let message = GoalTaskTimeline.limitReachedMessage(
            conversationID: UUID(),
            turnID: UUID(),
            maxAttempts: 5,
            goalTitles: ["发布 iOS 版本", "上传截图"]
        )

        #expect(message.content == "Goal 自动续跑已停止")
        #expect(message.metadata[MessageTimelineEvent.goalTaskContinuationActionKey] == MessageTimelineEvent.goalTaskContinuationLimitReached)
        #expect(message.metadata[MessageTimelineEvent.goalTaskContinuationGoalTitlesKey] == "发布 iOS 版本\n上传截图")
        #expect(message.metadata[MessageTimelineEvent.goalTaskContinuationReasonKey]?.contains("5") == true)
        #expect(MessageTimelineEvent.isTimelineEvent(message))
    }
}
