import Foundation
import LumiCoreKit
import Testing
@testable import AutoTaskPlugin

// 这些测试覆盖「无感自动续聊」的纯内存逻辑：续聊标记的一次性消费、
// 连续续聊计数与上限保护，以及 TaskContextChatMiddleware 在续聊轮注入
// 更强 system prompt 的行为。它们使用独立的临时 TaskStateManager，
// 不经过 LumiCore.configure，因此不受现有测试套件中那个致命错误的影响。

// MARK: - Helpers

private func makeTempManager() async -> TaskStateManager {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("auto-task-continuation-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return TaskStateManager(databaseRootURL: root)
}

private func makeContext(language: LumiConversationLanguage = .chinese) -> LumiSendContext {
    LumiSendContext(
        conversationID: UUID(),
        messages: [],
        conversationLanguage: language
    )
}

// MARK: - TaskStateManager: continuation flag

@Suite("AutoTask continuation flag")
struct AutoTaskContinuationFlagTests {
    @Test("consumeContinuation returns false when not marked")
    func consumeWithoutMarking() async {
        let manager = await makeTempManager()
        let result = await manager.consumeContinuation(conversationId: "conv")
        #expect(result == false)
    }

    @Test("mark then consume returns true once, then false")
    func markThenConsumeOnce() async {
        let manager = await makeTempManager()

        await manager.markContinuation(conversationId: "conv")
        #expect(await manager.consumeContinuation(conversationId: "conv") == true)
        // 第二次消费：标记已被消费，不应再次命中
        #expect(await manager.consumeContinuation(conversationId: "conv") == false)
    }

    @Test("marking one conversation does not affect another")
    func isolationBetweenConversations() async {
        let manager = await makeTempManager()

        await manager.markContinuation(conversationId: "conv-a")
        #expect(await manager.consumeContinuation(conversationId: "conv-b") == false)
        #expect(await manager.consumeContinuation(conversationId: "conv-a") == true)
    }
}

// MARK: - TaskStateManager: continuation count

@Suite("AutoTask continuation count")
struct AutoTaskContinuationCountTests {
    @Test("count increments up to the configured maximum")
    func incrementsUpToMax() async {
        let manager = await makeTempManager()
        let conv = "conv"

        for expected in 1...TaskStateManager.maxAutomaticContinuations {
            let count = await manager.incrementContinuationCount(conversationId: conv)
            #expect(count == expected)
        }
    }

    @Test("count returns nil once the maximum is exceeded, preventing further continuation")
    func returnsNilBeyondMax() async {
        let manager = await makeTempManager()
        let conv = "conv"

        for _ in 0..<TaskStateManager.maxAutomaticContinuations {
            _ = await manager.incrementContinuationCount(conversationId: conv)
        }
        // 已用满预算，再递增应被拒绝
        let overflow = await manager.incrementContinuationCount(conversationId: conv)
        #expect(overflow == nil)
    }

    @Test("reset zeroes the count so continuation budget is restored")
    func resetRestoresBudget() async {
        let manager = await makeTempManager()
        let conv = "conv"

        _ = await manager.incrementContinuationCount(conversationId: conv)
        _ = await manager.incrementContinuationCount(conversationId: conv)
        await manager.resetContinuationCount(conversationId: conv)

        // 归零后重新从 1 开始
        let count = await manager.incrementContinuationCount(conversationId: conv)
        #expect(count == 1)
    }

    @Test("counts are tracked per conversation independently")
    func perConversationTracking() async {
        let manager = await makeTempManager()

        let a = await manager.incrementContinuationCount(conversationId: "conv-a")
        let b1 = await manager.incrementContinuationCount(conversationId: "conv-b")
        let b2 = await manager.incrementContinuationCount(conversationId: "conv-b")

        #expect(a == 1)
        #expect(b1 == 1)
        #expect(b2 == 2)
    }
}

// MARK: - TaskContextChatMiddleware

@Suite("AutoTask continuation middleware")
struct AutoTaskContinuationMiddlewareTests {
    @Test("without a marked continuation, only the progress fragment is injected")
    func noContinuationInjectsProgressOnly() async throws {
        let manager = await makeTempManager()
        let convId = UUID()
        let convIdStr = convId.uuidString
        _ = try await manager.createTasks(
            conversationId: convIdStr,
            items: [(title: "任务一", detail: nil)]
        )

        let middleware = TaskContextChatMiddleware(manager: manager)
        let context = LumiSendContext(conversationID: convId, messages: [], conversationLanguage: .chinese)
        let prepared = try await middleware.prepare(context)

        // 进度片段一定存在
        #expect(prepared.systemPromptFragments.count == 1)
        #expect(prepared.systemPromptFragments.first?.contains("项目任务进度") == true)
    }

    @Test("a marked continuation injects the stronger continue-prompt fragment")
    func continuationInjectsContinuePrompt() async throws {
        let manager = await makeTempManager()
        let convId = UUID()
        let convIdStr = convId.uuidString
        _ = try await manager.createTasks(
            conversationId: convIdStr,
            items: [(title: "未完成任务", detail: nil)]
        )

        // 标记本轮为续聊（模拟 TurnCheckRuntime 触发前的置位）
        await manager.markContinuation(conversationId: convIdStr)

        let middleware = TaskContextChatMiddleware(manager: manager)
        let context = LumiSendContext(conversationID: convId, messages: [], conversationLanguage: .chinese)
        let prepared = try await middleware.prepare(context)

        // 进度片段 + 续聊片段
        #expect(prepared.systemPromptFragments.count == 2)
        let continuation = try #require(prepared.systemPromptFragments.last)
        #expect(continuation.contains("继续推进未完成任务"))
        #expect(continuation.contains("未完成任务"))
        #expect(continuation.contains("update_task"))
    }

    @Test("the continuation flag is consumed, so a subsequent turn is a normal turn")
    func continuationFlagIsOneShot() async throws {
        let manager = await makeTempManager()
        let convId = UUID()
        let convIdStr = convId.uuidString
        _ = try await manager.createTasks(
            conversationId: convIdStr,
            items: [(title: "任务", detail: nil)]
        )

        await manager.markContinuation(conversationId: convIdStr)
        let middleware = TaskContextChatMiddleware(manager: manager)
        let context = LumiSendContext(conversationID: convId, messages: [], conversationLanguage: .chinese)

        // 第一轮：续聊片段存在
        let first = try await middleware.prepare(context)
        #expect(first.systemPromptFragments.count == 2)

        // 第二轮：标记已被消费，只剩进度片段
        let second = try await middleware.prepare(context)
        #expect(second.systemPromptFragments.count == 1)
    }

    @Test("no fragments are injected when there are no tasks")
    func emptyTasksInjectsNothing() async throws {
        let manager = await makeTempManager()
        await manager.markContinuation(conversationId: UUID().uuidString)

        let middleware = TaskContextChatMiddleware(manager: manager)
        let context = makeContext()
        let prepared = try await middleware.prepare(context)

        #expect(prepared.systemPromptFragments.isEmpty)
    }

    @Test("the English continuation prompt is used for English conversations")
    func englishContinuationPrompt() async throws {
        let manager = await makeTempManager()
        let convId = UUID()
        let convIdStr = convId.uuidString
        _ = try await manager.createTasks(
            conversationId: convIdStr,
            items: [(title: "Pending task", detail: nil)]
        )

        await manager.markContinuation(conversationId: convIdStr)
        let middleware = TaskContextChatMiddleware(manager: manager)
        let context = LumiSendContext(conversationID: convId, messages: [], conversationLanguage: .english)
        let prepared = try await middleware.prepare(context)

        let continuation = try #require(prepared.systemPromptFragments.last)
        #expect(continuation.contains("Continue Pending Tasks"))
    }
}
