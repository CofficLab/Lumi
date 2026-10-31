import Foundation
import KitAgentTool
import KitLLM
import ProviderAgentLoop
import ProviderLifecycleHooks
import ProviderMessage
import Testing
@testable import GoalTaskPlugin

// serialized：这些测试共享 `GoalTaskPluginSupport._sharedManager` 静态状态。
extension SharedManagerSuite {

    @Suite("Goal Prompt Injection Hook")
    @MainActor
    struct GoalPromptInjectionHookTests {

        private func makeHarness() throws -> (manager: GoalStateManager, conversationID: UUID, tempDir: URL) {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("GoalPromptHookTest-\(UUID().uuidString)")
            let manager = try GoalStateManager(databaseRootURL: tempDir)
            GoalTaskPluginSupport._sharedManager = manager
            return (manager, UUID(), tempDir)
        }

        private func context(_ conversationID: UUID) -> WillSendToLLMContext {
            WillSendToLLMContext(
                messages: [LLMMessage(role: .user, content: "hello")],
                conversationID: conversationID
            )
        }

        private func systemTexts(_ result: WillSendToLLMContext) -> [String] {
            result.messages.filter { $0.role == .system }.map(\.content)
        }

        // MARK: - 无注入场景

        @Test("manager 未就绪时原样返回，不注入任何消息")
        func testNoManagerReturnsContextUnchanged() async throws {
            GoalTaskPluginSupport._sharedManager = nil
            let original = context(UUID())

            let result = await GoalPromptInjectionHook().apply(to: original)

            #expect(result.messages.count == original.messages.count)
            #expect(systemTexts(result).isEmpty)
        }

        @Test("无活跃 Goal 时不注入，不产生 token 开销")
        func testNoActiveGoalsInjectsNothing() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let original = context(conversationID)
            let result = await GoalPromptInjectionHook().apply(to: original)

            #expect(result.messages == original.messages)
            #expect(systemTexts(result).isEmpty)
        }

        // MARK: - blocked 场景

        @Test("只有 blocked Goal 时只注入等待指令，不叠加自主执行契约")
        func testBlockedGoalInjectsOnlyStopPrompt() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let created = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Blocked goal",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
            )
            _ = try await manager.updateGoalStatus(
                id: created.goal.id,
                status: .blocked,
                blockedReason: "missing credentials"
            )

            let result = await GoalPromptInjectionHook().apply(to: context(conversationID))
            let systems = systemTexts(result)

            #expect(systems.count == 1)
            let prompt = systems[0]
            #expect(prompt.contains("## 🎯 Goal Blocked"))
            #expect(prompt.contains("Blocked goal"))
            #expect(prompt.contains("**Reason:** missing credentials"))
            #expect(prompt.contains("STATUS: BLOCKED"))
            #expect(prompt.contains("Do NOT continue executing tasks"))
            // 关键：blocked 时不能同时注入自主执行契约，否则两条指令互相抵消
            #expect(prompt.contains("Autonomous Execution Contract") == false)
        }

        @Test("blocked Goal 没有阻塞原因时不输出 Reason 行")
        func testBlockedGoalWithoutReason() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let created = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Blocked without reason",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
            )
            _ = try await manager.updateGoalStatus(id: created.goal.id, status: .blocked)

            let result = await GoalPromptInjectionHook().apply(to: context(conversationID))
            let prompt = systemTexts(result)[0]

            #expect(prompt.contains("STATUS: BLOCKED"))
            #expect(prompt.contains("**Reason:**") == false)
        }

        // MARK: - 活跃 Goal 进度注入

        @Test("活跃 Goal 注入契约与进度，静态契约排在动态进度之前")
        func testActiveGoalInjectsContractBeforeProgress() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let created = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Ship the feature",
                description: "feature description",
                successCriteria: "tests pass",
                tasks: [
                    (title: "Design", description: "write design", executionContext: "docs/", parallelGroup: nil),
                    (title: "Implement", description: nil, executionContext: nil, parallelGroup: "A"),
                    (title: "Test", description: nil, executionContext: nil, parallelGroup: "A"),
                ]
            )

            let result = await GoalPromptInjectionHook().apply(to: context(conversationID))
            let systems = systemTexts(result)

            // 契约 + 每个活跃 goal 的进度
            #expect(systems.count == 2, "实际注入 \(systems.count) 段: \(systems.map { $0.prefix(40) })")
            guard systems.count == 2 else { return }
            #expect(systems[0].contains("Autonomous Execution Contract"))
            #expect(systems[1].contains("## 🎯 Current Goal"))

            let progress = systems[1]
            #expect(progress.contains("**Goal ID:** `\(created.goal.id)`"))
            #expect(progress.contains("**Title:** Ship the feature"))
            #expect(progress.contains("**Description:** feature description"))
            #expect(progress.contains("**Success Criteria:** tests pass"))
            #expect(progress.contains("**Progress:** 0/3 tasks done"))
            // 首个任务自动 in_progress，作为当前焦点并给出下一步指令
            #expect(progress.contains("**Current Focus:** Design"))
            #expect(progress.contains("_write design_"))
            #expect(progress.contains("_Context: docs/_"))
            #expect(progress.contains("status: \"completed\""))
            // 剩余任务列表
            #expect(progress.contains("**Remaining Tasks:**"))
            #expect(progress.contains("Implement"))
            #expect(progress.contains("Test"))
            // 有 in_progress 任务时走「当前焦点」分支，并行提示只在无焦点任务时出现
            #expect(progress.contains("Parallel group") == false)

            // 原有用户消息保留在最后
            #expect(result.messages.last?.content == "hello")
        }

        @Test("无 in_progress 任务且待办同组时提示可并行执行")
        func testPromptSuggestsParallelGroupWhenNoFocusTask() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let created = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Parallel goal",
                description: nil,
                successCriteria: nil,
                tasks: [
                    (title: "P1", description: nil, executionContext: nil, parallelGroup: "A"),
                    (title: "P2", description: nil, executionContext: nil, parallelGroup: "A"),
                    (title: "Solo", description: nil, executionContext: nil, parallelGroup: nil),
                ]
            )
            // 把首个任务退回 pending，使当前没有 in_progress 任务且首个待办属于 A 组
            _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .pending)

            let result = await GoalPromptInjectionHook().apply(to: context(conversationID))
            let systems = systemTexts(result)
            guard systems.count == 2 else {
                Issue.record("实际注入 \(systems.count) 段")
                return
            }
            let progress = systems[1]

            #expect(progress.contains("Parallel group **A**"))
            #expect(progress.contains("can run concurrently"))
            #expect(progress.contains("Update each one independently as it completes."))
            #expect(progress.contains("**Current Focus:**") == false)
        }

        @Test("失败任务计入进度行的失败数")
        func testFailedTasksCountedInProgress() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let created = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Partially failed",
                description: nil,
                successCriteria: nil,
                tasks: [
                    (title: "A", description: nil, executionContext: nil, parallelGroup: nil),
                    (title: "B", description: nil, executionContext: nil, parallelGroup: nil),
                    (title: "C", description: nil, executionContext: nil, parallelGroup: nil),
                ]
            )
            _ = try await manager.updateGoalTaskStatus(id: created.tasks[1].id, status: .completed)
            _ = try await manager.updateGoalTaskStatus(id: created.tasks[2].id, status: .failed)

            let result = await GoalPromptInjectionHook().apply(to: context(conversationID))
            let progress = systemTexts(result)[1]

            #expect(progress.contains("**Progress:** 1/3 tasks done (1 failed)"))
        }

        @Test("首个任务完成后提示下一个待办为 next task")
        func testPromptSuggestsNextTaskWhenNoneInProgress() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let created = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Sequential",
                description: nil,
                successCriteria: nil,
                tasks: [
                    (title: "First", description: nil, executionContext: nil, parallelGroup: nil),
                    (title: "Second", description: nil, executionContext: nil, parallelGroup: nil),
                ]
            )
            // 把首任务改为 pending，使当前没有 in_progress 任务
            _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .pending)

            let result = await GoalPromptInjectionHook().apply(to: context(conversationID))
            let progress = systemTexts(result)[1]

            #expect(progress.contains("Next task: **\"First\"**"))
            #expect(progress.contains("status: \"in_progress\""))
            #expect(progress.contains("**Current Focus:**") == false)
        }

        @Test("所有任务结束时提示验收并关闭 Goal")
        func testPromptWhenAllTasksFinished() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let created = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "All done goal",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "Only", description: nil, executionContext: nil, parallelGroup: nil)]
            )
            _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .completed)
            // 任务全完成会让 Goal 自动推导为 completed，这里手动改回 pending 以验证收尾分支
            _ = try await manager.updateGoalStatus(id: created.goal.id, status: .pending)

            let result = await GoalPromptInjectionHook().apply(to: context(conversationID))
            let progress = systemTexts(result)[1]

            #expect(progress.contains("All tasks are finished"))
            #expect(progress.contains("status: \"completed\""))
            #expect(progress.contains("**Remaining Tasks:**") == false)
        }

        @Test("多个活跃 Goal 各自注入一段进度")
        func testMultipleActiveGoalsInjectSeparateProgress() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            for title in ["Goal one", "Goal two"] {
                _ = try await manager.createGoal(
                    conversationId: conversationID.uuidString,
                    title: title,
                    description: nil,
                    successCriteria: nil,
                    tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
                )
            }

            let result = await GoalPromptInjectionHook().apply(to: context(conversationID))
            let systems = systemTexts(result)

            #expect(systems.count == 3)
            #expect(systems[0].contains("Autonomous Execution Contract"))
            #expect(systems[1].contains("Goal one"))
            #expect(systems[2].contains("Goal two"))
        }

        @Test("待办超过 10 个时截断并提示用 get_goal_progress 取全量")
        func testPendingTasksTruncatedBeyondTen() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let created = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Many tasks",
                description: nil,
                successCriteria: nil,
                tasks: (1...13).map { (title: "T\($0)", description: nil, executionContext: nil, parallelGroup: nil) }
            )
            // 让首任务回到 pending，剩下 13 个全是待办
            _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .pending)

            let result = await GoalPromptInjectionHook().apply(to: context(conversationID))
            let progress = systemTexts(result)[1]

            #expect(progress.contains("... and 3 more"))
            #expect(progress.contains("use `get_goal_progress` for the full list"))
            // 只列出前 10 条
            #expect(progress.contains("T10"))
            #expect(progress.contains("T11") == false)
        }

        // MARK: - 续跑标记

        @Test("消费到续跑标记时追加开场指令，且只生效一次")
        func testContinuationPromptConsumedOnce() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            _ = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Continuing goal",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
            )
            await manager.markContinuation(conversationId: conversationID.uuidString)

            let first = await GoalPromptInjectionHook().apply(to: context(conversationID))
            let firstSystems = systemTexts(first)
            #expect(firstSystems.count == 3)
            #expect(firstSystems[2].contains("Automatic Continuation"))
            #expect(firstSystems[2].contains("Do NOT summarize or recap"))

            // 标记已被消费，下一轮不再注入
            let second = await GoalPromptInjectionHook().apply(to: context(conversationID))
            #expect(systemTexts(second).count == 2)
        }

        @Test("没有续跑标记时不追加开场指令")
        func testNoContinuationPromptWithoutMarker() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            _ = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Normal goal",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "T", description: nil, executionContext: nil, parallelGroup: nil)]
            )

            let result = await GoalPromptInjectionHook().apply(to: context(conversationID))
            let systems = systemTexts(result)

            #expect(systems.count == 2)
            #expect(systems.contains { $0.contains("Automatic Continuation") } == false)
        }
    }
}

// MARK: - GoalTaskTurnFinishedHook

/// 记录 `runTurn` / `resumeTurn` 调用的 agentLoop 桩。
@MainActor
private final class NoopObserverHandle: AgentLoopObserverHandle {
    func cancel() {}
}

@MainActor
private final class SpyAgentLoop: AgentLoopProviding {
    var suspension: AgentLoopSuspension?
    var runTurnCount = 0
    var resumeTurnCount = 0
    var lastResumeRequest: AgentTurnResumeRequest?
    var resumeTurnError: Error?
    var conversationIDs: [UUID] = []

    func addAgentLoopObserver(_ callback: @escaping (AgentLoopEvent) -> Void) -> any AgentLoopObserverHandle {
        NoopObserverHandle()
    }
    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        runTurnCount += 1
        conversationIDs.append(conversationID)
        return .completed
    }
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        resumeTurnCount += 1
        lastResumeRequest = request
        if let resumeTurnError { throw resumeTurnError }
        return .completed
    }
    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { suspension }
    func lastFailure(for conversationID: UUID) -> AgentLoopFailure? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func isAutoReplySuppressed(for conversationID: UUID) -> Bool { false }
    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {}
    func retryTurn(in conversationID: UUID, after failedTurnID: UUID) async throws -> AgentLoopOutcome {
        .completed
    }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

/// 只记录插入消息的 messageManager 桩。
@MainActor
private final class SpyMessages: MessageManaging {
    var inserted: [Message] = []

    func messages(for conversationID: UUID) -> [Message] { inserted }
    func messagesSnapshot(in conversationID: UUID) async -> [Message] { inserted }
    func firstUserMessage(in conversationID: UUID) async -> Message? { inserted.first }
    func messagesForLLM(in conversationID: UUID) async -> [Message] { inserted }
    func messagePage(
        for conversationID: UUID, limit: Int, beforeMessageID: UUID?, includesToolMessages: Bool
    ) -> [Message] { inserted }
    func messagePageAsync(
        for conversationID: UUID, limit: Int, beforeMessageID: UUID?, includesToolMessages: Bool
    ) async -> [Message] { inserted }
    func hasEarlierMessages(
        for conversationID: UUID, beforeMessageID: UUID?, includesToolMessages: Bool
    ) -> Bool { false }
    func hasEarlierMessagesAsync(
        for conversationID: UUID, beforeMessageID: UUID?, includesToolMessages: Bool
    ) async -> Bool { false }
    func message(id: UUID, in conversationID: UUID) -> Message? { nil }
    func lastMessage(in conversationID: UUID) -> Message? { inserted.last }
    func messageCount(for conversationID: UUID) -> Int { inserted.count }
    func updateMessage(id: UUID, in conversationID: UUID, content: String) {}
    func deleteMessage(id: UUID, in conversationID: UUID) {}
    func clearMessages(in conversationID: UUID) { inserted.removeAll() }
    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
    ) {}
    func insertMessage(_ message: Message, to conversationID: UUID) { inserted.append(message) }
}

extension SharedManagerSuite {

    @Suite("Goal Turn Finished Hook")
    @MainActor
    struct GoalTaskTurnFinishedHookTests {

        private func makeHarness() throws -> (manager: GoalStateManager, conversationID: UUID, tempDir: URL) {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("GoalTurnHookTest-\(UUID().uuidString)")
            let manager = try GoalStateManager(databaseRootURL: tempDir)
            GoalTaskPluginSupport._sharedManager = manager
            return (manager, UUID(), tempDir)
        }

        private func turnContext(_ conversationID: UUID, reason: TurnEndReason?) -> TurnLifecycleContext {
            TurnLifecycleContext(conversationID: conversationID, turnID: UUID(), endReason: reason)
        }

        /// 等待 `Task { @MainActor ... }` 派发的续聊任务完成。
        private func settle() async {
            for _ in 0..<5 {
                await Task.yield()
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }

        @Test("非 completed / suspended 的结束原因不触发任何动作")
        func testIgnoredEndReasons() async throws {
            let (_, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }
            let agentLoop = SpyAgentLoop()
            let messages = SpyMessages()
            let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop, messages: messages)

            for reason in [TurnEndReason.failed, .cancelled, nil] {
                await hook.apply(to: turnContext(conversationID, reason: reason))
            }
            await settle()

            #expect(agentLoop.runTurnCount == 0)
            #expect(agentLoop.resumeTurnCount == 0)
            #expect(messages.inserted.isEmpty)
        }

        @Test("有活跃 Goal 且存在未完成任务时发起续跑并置位标记")
        func testContinuesWhenActiveGoalHasPendingTasks() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }
            let agentLoop = SpyAgentLoop()
            let messages = SpyMessages()
            let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop, messages: messages)

            _ = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Continue me",
                description: nil,
                successCriteria: nil,
                tasks: [
                    (title: "A", description: nil, executionContext: nil, parallelGroup: nil),
                    (title: "B", description: nil, executionContext: nil, parallelGroup: nil),
                ]
            )
            // A 完成，B 仍待办
            let goal = try #require(await manager.fetchGoals(conversationId: conversationID.uuidString).first)
            let tasks = await manager.fetchTasks(goalId: goal.id)
            _ = try await manager.updateGoalTaskStatus(id: tasks[0].id, status: .completed)

            await hook.apply(to: turnContext(conversationID, reason: .completed))
            await settle()

            #expect(agentLoop.runTurnCount == 1)
            #expect(agentLoop.conversationIDs == [conversationID])
            #expect(messages.inserted.count == 1)
            #expect(messages.inserted[0].content.contains("Goal 自动继续（1/5）"))
            // 标记已置位，供注入钩子消费
            #expect(await manager.consumeContinuation(conversationId: conversationID.uuidString) == true)
        }

        @Test("续跑次数耗尽后停止并把未完成 Goal 标记为失败")
        func testLimitReachedFailsGoals() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }
            let agentLoop = SpyAgentLoop()
            let messages = SpyMessages()
            let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop, messages: messages)

            _ = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Doomed goal",
                description: nil,
                successCriteria: nil,
                tasks: [
                    (title: "A", description: nil, executionContext: nil, parallelGroup: nil),
                    (title: "B", description: nil, executionContext: nil, parallelGroup: nil),
                ]
            )
            // 耗尽预算
            for _ in 0..<GoalStateManager.maxAutomaticContinuations {
                _ = await manager.incrementContinuationCount(conversationId: conversationID.uuidString)
            }

            await hook.apply(to: turnContext(conversationID, reason: .completed))
            await settle()

            #expect(agentLoop.runTurnCount == 0)
            #expect(messages.inserted.count == 1)
            #expect(messages.inserted[0].content.contains("Goal 自动续跑已停止"))

            let goal = try #require(await manager.fetchGoals(conversationId: conversationID.uuidString).first)
            #expect(goal.status == .failed)
            #expect(goal.failureReason?.contains("Automatic continuation limit reached") == true)
        }

        @Test("活跃 Goal 的任务已全部结束时不续跑")
        func testNoContinuationWhenNoOpenTasks() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }
            let agentLoop = SpyAgentLoop()
            let messages = SpyMessages()
            let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop, messages: messages)

            let created = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Finished",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "A", description: nil, executionContext: nil, parallelGroup: nil)]
            )
            _ = try await manager.updateGoalTaskStatus(id: created.tasks[0].id, status: .completed)

            await hook.apply(to: turnContext(conversationID, reason: .completed))
            await settle()

            #expect(agentLoop.runTurnCount == 0)
            #expect(messages.inserted.isEmpty)
        }

        @Test("全部 Goal 到达终态后清理并通知，不再续跑")
        func testCleansUpWhenAllGoalsTerminal() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }
            let agentLoop = SpyAgentLoop()
            let messages = SpyMessages()
            let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop, messages: messages)

            let created = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Wrap up",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "A", description: nil, executionContext: nil, parallelGroup: nil)]
            )
            _ = try await manager.updateGoalStatus(id: created.goal.id, status: .skipped)

            await hook.apply(to: turnContext(conversationID, reason: .completed))
            await settle()

            #expect(agentLoop.runTurnCount == 0)
            #expect(await manager.fetchGoals(conversationId: conversationID.uuidString).isEmpty)
            // 清理后预算应重置
            #expect(await manager.incrementContinuationCount(conversationId: conversationID.uuidString) == 1)
        }

        @Test("blocked Goal 不触发续跑（与注入钩子的活跃判定保持一致）")
        func testBlockedGoalDoesNotContinue() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }
            let agentLoop = SpyAgentLoop()
            let messages = SpyMessages()
            let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop, messages: messages)

            let created = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Blocked",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "A", description: nil, executionContext: nil, parallelGroup: nil)]
            )
            _ = try await manager.updateGoalStatus(id: created.goal.id, status: .blocked)

            await hook.apply(to: turnContext(conversationID, reason: .completed))
            await settle()

            #expect(agentLoop.runTurnCount == 0)
        }

        @Test("suspended 回合在活跃 Goal 时代答 ask_user 并恢复")
        func testSuspendedAutoAnswersAskUser() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let payload = """
            {"toolCallId":"ask_user","question":"Which database should we use?"}
            """
            let agentLoop = SpyAgentLoop()
            agentLoop.suspension = AgentLoopSuspension(
                suspensionID: "userInput:abc",
                conversationID: conversationID,
                toolCallID: "ask_user",
                kind: "userInput",
                payload: payload
            )
            let messages = SpyMessages()
            let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop, messages: messages)

            _ = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Active goal",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "A", description: nil, executionContext: nil, parallelGroup: nil)]
            )

            await hook.apply(to: turnContext(conversationID, reason: .suspended))
            await settle()

            #expect(agentLoop.resumeTurnCount == 1)
            #expect(agentLoop.lastResumeRequest?.suspensionID == "userInput:abc")
            // 代答内容要求模型自行拍板并继续
            #expect(agentLoop.lastResumeRequest?.answer.contains("Decide the most reasonable option yourself") == true)
            // 标记置位，使恢复后的那一轮同样按续跑注入指令
            #expect(await manager.consumeContinuation(conversationId: conversationID.uuidString) == true)
            // ask_user 代答不消耗续跑预算
            #expect(await manager.incrementContinuationCount(conversationId: conversationID.uuidString) == 1)
        }

        @Test("非 ask_user 的挂起点不被代答")
        func testNonAskUserSuspensionIgnored() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            // 授权等待：共用 userInput 前缀但 toolCallId 不同
            let agentLoop = SpyAgentLoop()
            agentLoop.suspension = AgentLoopSuspension(
                suspensionID: "userInput:abc",
                conversationID: conversationID,
                toolCallID: "request_permission",
                kind: "userInput",
                payload: #"{"toolCallId":"request_permission","question":"Allow?"}"#
            )
            let messages = SpyMessages()
            let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop, messages: messages)

            _ = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Active goal",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "A", description: nil, executionContext: nil, parallelGroup: nil)]
            )

            await hook.apply(to: turnContext(conversationID, reason: .suspended))
            await settle()

            #expect(agentLoop.resumeTurnCount == 0)
        }

        @Test("question 为空的 ask_user 不代答（参数校验失败不构成真正提问）")
        func testEmptyQuestionNotAnswered() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let agentLoop = SpyAgentLoop()
            agentLoop.suspension = AgentLoopSuspension(
                suspensionID: "userInput:abc",
                conversationID: conversationID,
                toolCallID: "ask_user",
                kind: "userInput",
                payload: #"{"toolCallId":"ask_user","question":""}"#
            )
            let messages = SpyMessages()
            let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop, messages: messages)

            _ = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Active goal",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "A", description: nil, executionContext: nil, parallelGroup: nil)]
            )

            await hook.apply(to: turnContext(conversationID, reason: .suspended))
            await settle()

            #expect(agentLoop.resumeTurnCount == 0)
        }

        @Test("ask_user 代答预算耗尽后交回用户")
        func testAskUserBudgetExhausted() async throws {
            let (manager, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let agentLoop = SpyAgentLoop()
            agentLoop.suspension = AgentLoopSuspension(
                suspensionID: "userInput:abc",
                conversationID: conversationID,
                toolCallID: "ask_user",
                kind: "userInput",
                payload: #"{"toolCallId":"ask_user","question":"Which one?"}"#
            )
            let messages = SpyMessages()
            let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop, messages: messages)

            _ = try await manager.createGoal(
                conversationId: conversationID.uuidString,
                title: "Active goal",
                description: nil,
                successCriteria: nil,
                tasks: [(title: "A", description: nil, executionContext: nil, parallelGroup: nil)]
            )
            for _ in 0..<GoalStateManager.maxAutomaticAskUserAnswers {
                _ = await manager.incrementAskUserAnswerCount(conversationId: conversationID.uuidString)
            }

            await hook.apply(to: turnContext(conversationID, reason: .suspended))
            await settle()

            #expect(agentLoop.resumeTurnCount == 0)
        }

        @Test("无活跃 Goal 时挂起回合不被代答")
        func testNoActiveGoalNoAutoAnswer() async throws {
            let (_, conversationID, tempDir) = try makeHarness()
            defer {
                GoalTaskPluginSupport._sharedManager = nil
                try? FileManager.default.removeItem(at: tempDir)
            }

            let agentLoop = SpyAgentLoop()
            agentLoop.suspension = AgentLoopSuspension(
                suspensionID: "userInput:abc",
                conversationID: conversationID,
                toolCallID: "ask_user",
                kind: "userInput",
                payload: #"{"toolCallId":"ask_user","question":"Which one?"}"#
            )
            let hook = GoalTaskTurnFinishedHook(agentLoop: agentLoop, messages: SpyMessages())

            await hook.apply(to: turnContext(conversationID, reason: .suspended))
            await settle()

            #expect(agentLoop.resumeTurnCount == 0)
        }
    }
}
