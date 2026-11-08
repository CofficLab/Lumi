import Foundation
import ProviderConversation
import Testing
@testable import GoalTaskPlugin

/// 回归 #771：删除会话时，该会话的 Goals 必须一起从 `goals.sqlite` 清掉。
@MainActor
@Suite("GoalTask 会话删除清理", .serialized)
struct GoalTaskConversationCleanupTests {
    private func makeManager() throws -> (GoalStateManager, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoalTaskCleanup-\(UUID().uuidString)", isDirectory: true)
        return (try GoalStateManager(databaseRootURL: directory), directory)
    }

    private func makeGoal(
        in manager: GoalStateManager,
        conversationID: UUID,
        title: String
    ) async throws {
        _ = try await manager.createGoal(
            conversationId: conversationID.uuidString,
            title: title,
            description: nil,
            successCriteria: nil,
            tasks: [(title: "Task", description: nil, executionContext: nil, parallelGroup: nil)]
        )
    }

    @Test("删除会话时只清理该会话的 Goals")
    func deletingConversationRemovesOnlyItsGoals() async throws {
        let (manager, directory) = try makeManager()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversations = DefaultConversationManager()
        let targetID = try conversations.createConversation(
            title: "Target",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        let otherID = try conversations.createConversation(
            title: "Other",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        try await makeGoal(in: manager, conversationID: targetID, title: "Target goal")
        try await makeGoal(in: manager, conversationID: otherID, title: "Other goal")

        let observer = GoalTaskConversationDeletionObserver(conversations: conversations) { conversationID in
            try? await manager.deleteAllGoals(conversationId: conversationID.uuidString)
        }
        defer { observer.cancel() }

        conversations.deleteConversation(id: targetID)
        await observer.waitForPendingDeletion()

        #expect(await manager.fetchGoals(conversationId: targetID.uuidString).isEmpty)
        #expect(await manager.fetchGoals(conversationId: otherID.uuidString).count == 1)
    }

    @Test("删除多个会话时逐个清理")
    func deletingMultipleConversationsRemovesEachGoalSet() async throws {
        let (manager, directory) = try makeManager()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversations = DefaultConversationManager()
        let firstID = try conversations.createConversation(
            title: "First",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        let secondID = try conversations.createConversation(
            title: "Second",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        try await makeGoal(in: manager, conversationID: firstID, title: "First goal")
        try await makeGoal(in: manager, conversationID: secondID, title: "Second goal")

        let observer = GoalTaskConversationDeletionObserver(conversations: conversations) { conversationID in
            try? await manager.deleteAllGoals(conversationId: conversationID.uuidString)
        }
        defer { observer.cancel() }

        conversations.deleteConversation(id: firstID)
        await observer.waitForPendingDeletion()
        conversations.deleteConversation(id: secondID)
        await observer.waitForPendingDeletion()

        #expect(await manager.fetchGoals(conversationId: firstID.uuidString).isEmpty)
        #expect(await manager.fetchGoals(conversationId: secondID.uuidString).isEmpty)
    }
}
