import Foundation
import ProviderConversation
import ProviderMessageSender
import Testing
@testable import GoalTaskPlugin

// 依赖 `GoalTaskPluginSupport._sharedManager`（fork 走 capability adapter），
// 故挂在串行父 suite 下，避免与其他 suite 争抢静态状态。
extension SharedManagerSuite {

    @Suite("Goal Fork Coordinator")
    @MainActor
    struct GoalForkCoordinatorTests {

        /// 记录调用序列的 `GoalForkCapability` 桩。
        @MainActor
        private final class SpyCapability: GoalForkCapability {
            var createError: Error?
            var forkError: Error?
            /// `commitUserMessage` 返回 nil 时模拟空 prompt。
            var commitReturnsNil = false
            var commitError: Error?
            /// fork 返回的 Goal 的描述与成功标准；默认均带值，供「区块应被省略」的用例置空。
            var forkedDescription: String? = "forked description"
            var forkedCriteria: String? = "forked criteria"

            var createdConversations: [String] = []
            var discardedConversations: [UUID] = []
            var forkedGoalIDs: [(id: String, into: UUID)] = []
            var committedTexts: [(text: String, conversationID: UUID)] = []
            var startedTurns = 0

            func createConversation(title: String) throws -> UUID {
                if let createError { throw createError }
                createdConversations.append(title)
                return UUID()
            }

            func discardConversation(id: UUID) {
                discardedConversations.append(id)
            }

            func forkGoal(id: String, into conversationID: UUID) async throws -> Goal {
                forkedGoalIDs.append((id, conversationID))
                if let forkError { throw forkError }
                return Goal(
                    conversationId: conversationID.uuidString,
                    title: "Forked goal",
                    goalDescription: forkedDescription,
                    successCriteria: forkedCriteria
                )
            }

            func commitUserMessage(_ text: String, conversationID: UUID) throws -> MessageSendCommit? {
                if let commitError { throw commitError }
                committedTexts.append((text, conversationID))
                return commitReturnsNil
                    ? nil
                    : MessageSendCommit(conversationID: conversationID, userMessageID: UUID())
            }

            func startTurn(for commit: MessageSendCommit) async {
                startedTurns += 1
            }
        }

        private enum StubError: Error { case boom }

        private func makeGoal(
            title: String = "Original goal",
            description: String? = "goal description",
            criteria: String? = "success criteria"
        ) -> GoalDisplayItem {
            GoalDisplayItem(from: Goal(
                conversationId: "source",
                title: title,
                goalDescription: description,
                successCriteria: criteria,
                status: .inProgress
            ))
        }

        private func makeTasks(_ entries: [(String, GoalTask.TaskStatus)]) -> [GoalTaskDisplayItem] {
            entries.map { title, status in
                GoalTaskDisplayItem(from: GoalTask(
                    goalId: "source",
                    title: title,
                    taskDescription: nil,
                    executionContext: nil,
                    status: status,
                    order: 0,
                    parallelGroup: nil
                ))
            }
        }

        // MARK: - 正常路径

        @Test("fork 后建会话、复制 Goal、发消息并启动回合")
        func testForkAndStartHappyPath() async throws {
            let capability = SpyCapability()
            let coordinator = GoalForkCoordinator(capability: capability)

            try await coordinator.forkAndStart(goal: makeGoal(), tasks: [])

            #expect(capability.createdConversations == ["Original goal"])
            #expect(capability.forkedGoalIDs.count == 1)
            // 复制与提交必须落在同一个新会话上
            let newConversation = try #require(capability.forkedGoalIDs.first?.into)
            #expect(capability.committedTexts.first?.conversationID == newConversation)
            #expect(capability.startedTurns == 1)
            #expect(capability.discardedConversations.isEmpty)
        }

        @Test("开场指令陈述目标与描述、成功标准，不下继续执行指令")
        func testResumePromptContent() async throws {
            let capability = SpyCapability()
            let coordinator = GoalForkCoordinator(capability: capability)

            try await coordinator.forkAndStart(goal: makeGoal(), tasks: [])

            let prompt = try #require(capability.committedTexts.first?.text)
            #expect(prompt.contains("这个对话延续自另一个对话中的目标"))
            #expect(prompt.contains("## Goal"))
            #expect(prompt.contains("Forked goal"))
            #expect(prompt.contains("forked description"))
            #expect(prompt.contains("成功标准：forked criteria"))
            #expect(capability.startedTurns == 1)
        }

        @Test("只列出未完成任务，已完成的不出现在开场指令中")
        func testResumePromptListsOnlyOutstandingTasks() async throws {
            let capability = SpyCapability()
            let coordinator = GoalForkCoordinator(capability: capability)

            try await coordinator.forkAndStart(goal: makeGoal(), tasks: makeTasks([
                ("已完成", .completed),
                ("待办一", .pending),
                ("进行中", .inProgress),
                ("已跳过", .skipped),
                ("已失败", .failed),
            ]))

            let prompt = try #require(capability.committedTexts.first?.text)
            #expect(prompt.contains("## 未完成的任务"))
            #expect(prompt.contains("待办一（pending）"))
            #expect(prompt.contains("进行中（in_progress）"))
            #expect(prompt.contains("已完成") == false)
            #expect(prompt.contains("已跳过") == false)
            #expect(prompt.contains("已失败") == false)
        }

        @Test("全部任务已结束时开场指令不含未完成区块")
        func testResumePromptWithoutOutstandingTasks() async throws {
            let capability = SpyCapability()
            let coordinator = GoalForkCoordinator(capability: capability)

            try await coordinator.forkAndStart(
                goal: makeGoal(),
                tasks: makeTasks([("已完成", .completed), ("已跳过", .skipped)])
            )

            let prompt = try #require(capability.committedTexts.first?.text)
            #expect(prompt.contains("## 未完成的任务") == false)
        }

        @Test("fork 副本的描述与成功标准为空时对应区块被省略")
        func testResumePromptOmitsEmptyDescriptionAndCriteria() async throws {
            let capability = SpyCapability()
            capability.forkedDescription = nil
            capability.forkedCriteria = nil
            let coordinator = GoalForkCoordinator(capability: capability)

            try await coordinator.forkAndStart(
                goal: makeGoal(description: nil, criteria: nil),
                tasks: []
            )

            let prompt = try #require(capability.committedTexts.first?.text)
            #expect(prompt.contains("## Goal"))
            #expect(prompt.contains("Forked goal"))
            #expect(prompt.contains("成功标准：") == false)
            #expect(capability.startedTurns == 1)
        }

        @Test("fork 副本的描述为空串时同样省略该区块")
        func testResumePromptOmitsEmptyStringDescription() async throws {
            let capability = SpyCapability()
            capability.forkedDescription = ""
            capability.forkedCriteria = ""
            let coordinator = GoalForkCoordinator(capability: capability)

            try await coordinator.forkAndStart(goal: makeGoal(), tasks: [])

            let prompt = try #require(capability.committedTexts.first?.text)
            #expect(prompt.contains("成功标准：") == false)
            #expect(capability.startedTurns == 1)
        }

        // MARK: - 失败回收

        @Test("建对话失败时向上抛出且不执行后续步骤")
        func testCreateConversationFailurePropagates() async throws {
            let capability = SpyCapability()
            capability.createError = StubError.boom
            let coordinator = GoalForkCoordinator(capability: capability)

            await #expect(throws: StubError.self) {
                try await coordinator.forkAndStart(goal: makeGoal(), tasks: [])
            }
            #expect(capability.forkedGoalIDs.isEmpty)
            #expect(capability.startedTurns == 0)
            #expect(capability.discardedConversations.isEmpty)
        }

        @Test("复制 Goal 失败时回收刚建的空会话，不留孤儿对话")
        func testForkFailureDiscardsConversation() async throws {
            let capability = SpyCapability()
            capability.forkError = StubError.boom
            let coordinator = GoalForkCoordinator(capability: capability)

            await #expect(throws: StubError.self) {
                try await coordinator.forkAndStart(goal: makeGoal(), tasks: [])
            }
            // 已建对话但复制失败，必须被回收
            #expect(capability.createdConversations.count == 1)
            #expect(capability.discardedConversations.count == 1)
            #expect(capability.committedTexts.isEmpty)
            #expect(capability.startedTurns == 0)
        }

        @Test("提交消息返回 nil 时抛 emptyPrompt 并回收会话")
        func testEmptyCommitThrowsAndDiscards() async throws {
            let capability = SpyCapability()
            capability.commitReturnsNil = true
            let coordinator = GoalForkCoordinator(capability: capability)

            await #expect(throws: GoalForkError.emptyPrompt) {
                try await coordinator.forkAndStart(goal: makeGoal(), tasks: [])
            }
            #expect(capability.discardedConversations.count == 1)
            #expect(capability.startedTurns == 0)
        }

        @Test("提交消息抛错时同样回收会话")
        func testCommitFailureDiscards() async throws {
            let capability = SpyCapability()
            capability.commitError = StubError.boom
            let coordinator = GoalForkCoordinator(capability: capability)

            await #expect(throws: StubError.self) {
                try await coordinator.forkAndStart(goal: makeGoal(), tasks: [])
            }
            #expect(capability.discardedConversations.count == 1)
            #expect(capability.startedTurns == 0)
        }
    }
}

// MARK: - GoalForkError

@Suite("Goal Fork Error Tests")
struct GoalForkErrorTests {

    @Test("每个 case 都有面向用户的文案")
    func testErrorDescriptions() {
        #expect(GoalForkError.managerUnavailable.errorDescription == "Goal data is not ready yet.")
        #expect(GoalForkError.emptyPrompt.errorDescription == "Failed to start the new conversation.")
    }
}
