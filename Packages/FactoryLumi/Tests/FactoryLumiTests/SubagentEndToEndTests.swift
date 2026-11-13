import Foundation
import KernelCore
import KitAgentTool
import KitLLM
import PluginSubagent
import PluginToolManager
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderMessageRendering
import ProviderStorage
import ProviderToolManager
import Testing
@testable import FactoryLumi

/// 「父会话调用 run_subagent → 隐藏子会话跑完一个回合 → 父工具结果只拿到结论」
/// 这条主链路的端到端验证（#1313 Task 2）。
///
/// 与 FinderEndToEndTests 同一模式：真实 Kernel、真实工具管理器提交 ToolJob，
/// 只有 LLM 换成脚本化替身——替身在 PluginAgentLoop 启动**之前**注入内核，
/// 因为 AgentLoopManager 在 onBoot 时快照持有 LLMManaging。
@MainActor
@Suite("FactoryLumi · PluginSubagent 端到端", .serialized)
struct SubagentEndToEndTests {

    @Test("同步委托只返回子代理结论与用量摘要，子会话对列表隐藏")
    func syncDelegationReturnsConclusionOnly() async throws {
        let stub = ScriptedLLMManager()
        let task = "Find the answer to life, the universe, and everything."
        let conclusion = "The answer is 42."
        stub.scripts[task] = .text(conclusion)
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))

        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Answer lookup",
            conversationID: parentID
        )

        #expect(result.isError == false)
        #expect(result.content.contains(conclusion))
        #expect(result.content.contains("[subagent]"))

        // 子会话存在、挂在父会话下，但不出现在可见列表里。
        let all = await conversations.fetchConversationPage(
            limit: 100, beforeUpdatedAt: nil, beforeID: nil, includingChildConversations: true
        )
        let child = try #require(all.first(where: { $0.parentConversationID == parentID }))
        #expect(conversations.conversations.contains(where: { $0.id == child.id }) == false)

        // 子会话自己的历史完整保留任务与结论。
        let childMessages = messages.messages(for: child.id)
        #expect(childMessages.contains(where: { $0.role == .user && $0.content == task }))
        #expect(childMessages.contains(where: { $0.role == .assistant && $0.content.contains(conclusion) }))

        // 父会话历史里没有任何子会话转录——结论只经由工具结果回流。
        #expect(messages.messages(for: parentID).allSatisfy { !$0.content.contains(conclusion) })
    }

    @Test("超长结论被截断，工具结果不会撑爆父上下文")
    func longConclusionIsCapped() async throws {
        let stub = ScriptedLLMManager()
        let task = "Produce a very long report."
        stub.scripts[task] = .text(String(repeating: "A", count: 30_000))
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Long report",
            conversationID: parentID
        )

        #expect(result.isError == false)
        // 实现侧上限 8000 字符，另加用量摘要与截断标记的余量。
        #expect(result.content.count <= 8_200)
        #expect(result.content.contains("[truncated]"))
    }

    @Test("子回合失败时工具抛出执行错误而不是成功字符串")
    func childFailureBecomesToolError() async throws {
        let stub = ScriptedLLMManager()
        let task = "This task will fail."
        stub.scripts[task] = .failure("model exploded")
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Failing task",
            conversationID: parentID
        )

        #expect(result.isError == true)
        #expect(result.content.contains("run_subagent"))
        #expect(result.content.contains("Subagent turn failed"))
    }

    @Test("同一回合三路委托并发执行，各自只返回结论")
    func threeDelegationsInOneTurnRunConcurrently() async throws {
        let stub = ScriptedLLMManager()
        let tasks = (1...3).map { "Parallel task number \($0)." }
        let conclusions = (1...3).map { "Conclusion number \($0)." }
        for (task, conclusion) in zip(tasks, conclusions) {
            stub.scripts[task] = .text(conclusion)
            stub.delays[task] = 0.6
        }
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        // 一条助手消息派发三个委托：同一 turnID 即同一调度作用域，
        // 只有声明 .parallelReadOnly 的工具才允许在其中并发。
        let turnID = UUID()
        async let first = runSubagent(
            toolManager: toolManager, task: tasks[0], description: "Task one",
            conversationID: parentID, turnID: turnID
        )
        async let second = runSubagent(
            toolManager: toolManager, task: tasks[1], description: "Task two",
            conversationID: parentID, turnID: turnID
        )
        async let third = runSubagent(
            toolManager: toolManager, task: tasks[2], description: "Task three",
            conversationID: parentID, turnID: turnID
        )
        let results = try await [first, second, third]

        for (result, conclusion) in zip(results, conclusions) {
            #expect(result.isError == false)
            #expect(result.content.contains(conclusion))
        }

        // 结构性并发断言：最晚的开始早于最早的结束，即三段执行区间有公共
        // 重叠。不依赖 wall-clock 总时长，避免机器快慢造成假阴/假阳。
        #expect(stub.intervals.count == 3)
        let starts = stub.intervals.values.map(\.start)
        let ends = stub.intervals.values.compactMap(\.end)
        #expect(try #require(starts.max()) < #require(ends.min()))

        let all = await conversations.fetchConversationPage(
            limit: 100, beforeUpdatedAt: nil, beforeID: nil, includingChildConversations: true
        )
        #expect(all.filter { $0.parentConversationID == parentID }.count == 3)
    }

    @Test("子回合工具表不得包含 run_subagent 与副作用工具")
    func childToolRegistryHasNoRecursionAndOnlyReadOnlyTools() async throws {
        let stub = ScriptedLLMManager()
        let task = "Inspect something read-only."
        stub.scripts[task] = .text("Inspected.")
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        // 父侧注册表里 run_subagent 必须在场，否则「子表没有它」是空断言。
        #expect(toolManager.tool(named: "run_subagent") != nil)

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Read-only inspection",
            conversationID: parentID
        )
        #expect(result.isError == false)

        let childRequest = try #require(
            stub.requests.first(where: {
                $0.messages.last(where: { $0.role == .user })?.content == task
            })
        )
        let childSchemas = try #require(childRequest.tools)
        #expect(childSchemas.isEmpty == false)
        #expect(childSchemas.contains(where: { $0.name == "run_subagent" }) == false)

        // 子表里的每个工具都必须是只读并发能力，副作用/交互工具一律不进子回合。
        let registered = toolManager.allTools()
        for schema in childSchemas {
            let tool = try #require(registered.first(where: { $0.name == schema.name }))
            #expect(tool.executionCapability == .parallelReadOnly)
        }
    }

    @Test("取消父 Job 必须级联停止子回合")
    func cancellingParentJobStopsChildTurn() async throws {
        let stub = ScriptedLLMManager()
        let task = "A long-running delegated task."
        stub.scripts[task] = .text("Should never be delivered.")
        stub.delays[task] = 30
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let agentLoop = try #require(kernel.resolveProvider((any AgentLoopProviding).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let arguments = try JSONSerialization.data(
            withJSONObject: ["task": task, "description": "Long task"]
        )
        let call = KitAgentTool.ToolCall(
            id: UUID().uuidString,
            name: "run_subagent",
            arguments: String(decoding: arguments, as: UTF8.self)
        )
        let turnID = UUID()
        let jobs = toolManager.submit(
            [call], policy: .autoExecute, conversationID: parentID, turnID: turnID
        )
        let job = try #require(jobs.first)

        // 等子回合真正开跑（LLM 请求已发出）再取消，覆盖「执行中取消」路径。
        let startedDeadline = Date().addingTimeInterval(10)
        while Date() < startedDeadline {
            if stub.requests.contains(where: {
                $0.messages.last(where: { $0.role == .user })?.content == task
            }) { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(stub.requests.contains(where: {
            $0.messages.last(where: { $0.role == .user })?.content == task
        }))

        let all = await conversations.fetchConversationPage(
            limit: 100, beforeUpdatedAt: nil, beforeID: nil, includingChildConversations: true
        )
        let child = try #require(all.first(where: { $0.parentConversationID == parentID }))

        toolManager.cancelJob(job.id)

        let stopDeadline = Date().addingTimeInterval(10)
        var stopped = false
        while Date() < stopDeadline {
            let snapshot = toolManager.job(for: job.id)
            if snapshot?.status.isTerminal == true, agentLoop.isRunning(for: child.id) == false {
                stopped = true
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(stopped)
        let finalStatus = try #require(toolManager.job(for: job.id)).status
        #expect(finalStatus == .cancelled || finalStatus == .failed)
        // 子回合的 LLM 请求被取消打断，没有产出完整响应。
        #expect(stub.intervals[task]?.end == nil)
    }

    @Test("子会话内不得再次调用 run_subagent")
    func delegationFromChildConversationIsRejected() async throws {
        let stub = ScriptedLLMManager()
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )
        let childID = try await conversations.createConversationAndWait(
            title: "Child", projectPath: nil, modelID: nil, parentConversationID: parentID
        )

        // 即使模型幻觉出委托调用（工具表已过滤，但全局注册表仍在），
        // 执行入口也必须拒绝，递归在任何路径下都不可能发生。
        let result = try await runSubagent(
            toolManager: toolManager,
            task: "Try to recurse.",
            description: "Recursion attempt",
            conversationID: childID
        )
        #expect(result.isError == true)
        #expect(result.content.contains("recursion"))
    }

    @Test("工具描述包含委托时机、结论导向与不重复委托指导")
    func descriptionTeachesWhenToDelegate() throws {
        let stub = ScriptedLLMManager()
        let kernel = try makeKernel(stub: stub)
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let tool = try #require(toolManager.tool(named: "run_subagent"))

        // 指导文案是 prompt 级契约：模型靠它决定何时委托、何时直接做。
        // 锁定关键语义词，防止后续改写把指导改丢。
        let description = tool.description(for: .english).lowercased()
        #expect(description.contains("parallel"))
        #expect(description.contains("directly"))
        #expect(description.contains("duplicate"))
        #expect(description.contains("self-contained"))
        #expect(description.contains("conclusion"))
    }

    @Test("自定义结论上限生效，超出部分截断")
    func customConclusionCapIsRespected() async throws {
        let stub = ScriptedLLMManager()
        let task = "Produce a long report with a custom cap."
        stub.scripts[task] = .text(String(repeating: "B", count: 30_000))
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Custom cap",
            conversationID: parentID,
            extraArguments: ["max_characters": 1_000]
        )
        #expect(result.isError == false)
        #expect(result.content.count <= 1_200)
        #expect(result.content.contains("[truncated]"))
    }

    @Test("越界结论上限不得突破硬上限，也不得低于下限")
    func outOfRangeConclusionCapIsClamped() async throws {
        let stub = ScriptedLLMManager()
        let highTask = "Report with an oversized cap request."
        let lowTask = "Report with an undersized cap request."
        stub.scripts[highTask] = .text(String(repeating: "C", count: 30_000))
        stub.scripts[lowTask] = .text(String(repeating: "D", count: 30_000))
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        // 远超硬上限的请求被钳制回 8000，不能撑爆父上下文。
        let high = try await runSubagent(
            toolManager: toolManager,
            task: highTask,
            description: "Oversized cap",
            conversationID: parentID,
            extraArguments: ["max_characters": 999_999]
        )
        #expect(high.isError == false)
        #expect(high.content.count <= 8_200)
        #expect(high.content.contains("[truncated]"))

        // 低于下限的请求被钳制到 500，而不是产出空结论或崩溃。
        let low = try await runSubagent(
            toolManager: toolManager,
            task: lowTask,
            description: "Undersized cap",
            conversationID: parentID,
            extraArguments: ["max_characters": 1]
        )
        #expect(low.isError == false)
        #expect(low.content.count <= 700)
        #expect(low.content.contains("[truncated]"))
    }

    @Test("非法结论上限参数回退默认值而不是崩溃")
    func invalidConclusionCapFallsBackToDefault() async throws {
        let stub = ScriptedLLMManager()
        let task = "Report with an invalid cap argument."
        stub.scripts[task] = .text(String(repeating: "E", count: 30_000))
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Invalid cap",
            conversationID: parentID,
            extraArguments: ["max_characters": "not-a-number"]
        )
        #expect(result.isError == false)
        #expect(result.content.count <= 8_200)
        #expect(result.content.contains("[truncated]"))
    }

    // MARK: - 后台模式（#1313 Task 5，复用 #1307 登记表/通知）

    @Test("后台委托立即返回任务 ID，子回合继续在后台跑")
    func backgroundDelegationReturnsImmediatelyWithTaskID() async throws {
        let stub = ScriptedLLMManager()
        let task = "A background delegated task."
        let conclusion = "Background conclusion."
        stub.scripts[task] = .text(conclusion)
        stub.delays[task] = 1.0
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let registry = try #require(kernel.resolveProvider(BackgroundTaskRegistry.self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Background task",
            conversationID: parentID,
            extraArguments: ["run_in_background": true]
        )

        #expect(result.isError == false)
        #expect(result.content.contains("Background task ID:"))
        // 文案一致性：后台派发不得再催模型去读输出文件，而应结束回合等通知。
        #expect(result.content.contains("end your turn"))
        #expect(!result.content.contains("check interim output"))
        // 立即返回的证据：返回那一刻子回合的 LLM 请求还没结束。
        #expect(stub.intervals[task]?.end == nil)

        let record = try #require(await registry.tasks(forConversationID: parentID).first)
        #expect(record.status == .running)
        #expect(result.content.contains(record.id))
        #expect(result.content.contains(record.outputPath))

        // 子回合跑完后登记表落到终态，结论写进输出文件。
        let deadline = Date().addingTimeInterval(10)
        var finished: BackgroundTaskRecord?
        while Date() < deadline {
            if let snapshot = await registry.task(for: record.id), snapshot.status != .running {
                finished = snapshot
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let final = try #require(finished)
        #expect(final.status == .completed)
        let contents = (try? String(contentsOf: URL(fileURLWithPath: final.outputPath), encoding: .utf8)) ?? ""
        #expect(contents.contains(conclusion))
    }

    @Test("空闲父会话被完成通知唤醒，通知恰好一条且携带结论")
    func idleParentIsWokenWithExactlyOneConclusionNotification() async throws {
        let stub = ScriptedLLMManager()
        let task = "Background task for idle wake."
        let conclusion = "The idle wake answer is 42."
        stub.scripts[task] = .text(conclusion)
        stub.delays[task] = 0.5
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Idle wake",
            conversationID: parentID,
            extraArguments: ["run_in_background": true]
        )
        #expect(result.isError == false)

        let notifications = try await waitForNotifications(
            messages: messages, conversationID: parentID, count: 1
        )
        let notification = try #require(notifications.first)
        #expect(notification.role == .user)
        #expect(notification.content.contains(conclusion))
        // 子代理任务的通知直接给出结论并要求转述，不再让模型去翻输出文件。
        #expect(notification.content.contains("Subagent conclusion:"))
        #expect(!notification.content.contains("read_file"))

        // 唤醒回合真的起了：LLM 收到以通知为最后一条用户消息的请求。
        let wakeDeadline = Date().addingTimeInterval(10)
        var woke = false
        while Date() < wakeDeadline {
            if stub.requests.contains(where: {
                $0.messages.last(where: { $0.role == .user })?.content.contains("Background task") == true
            }) {
                woke = true
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(woke)

        // 恰好一次：再等一段时间也不得出现第二条通知。
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(notificationMessages(messages: messages, conversationID: parentID).count == 1)
    }

    @Test("父回合正忙时通知入队，回合结束后排空并唤醒")
    func busyParentDrainsNotificationAfterTurnFinishes() async throws {
        let stub = ScriptedLLMManager()
        let parentPrompt = "Keep the parent busy."
        let slowTool = SlowTestTool(duration: 1.5)
        stub.scriptQueues[parentPrompt] = [
            .toolCalls([LLMToolCall(id: "call-slow", name: slowTool.name, arguments: "{}")]),
            .text("Parent work done."),
        ]
        let task = "Background task while parent busy."
        let conclusion = "Busy-drain conclusion."
        stub.scripts[task] = .text(conclusion)
        stub.delays[task] = 0.3
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))
        let registry = try #require(kernel.resolveProvider(BackgroundTaskRegistry.self))
        toolManager.add(slowTool, pluginID: "com.coffic.lumi.tests.subagent-e2e")
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        // 插入用户消息触发真实父回合；慢工具把回合撑住 1.5 秒。
        messages.insertMessage(
            Message(conversationID: parentID, role: .user, content: parentPrompt),
            to: parentID
        )
        let slowStartedDeadline = Date().addingTimeInterval(10)
        while Date() < slowStartedDeadline, !slowTool.started {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(slowTool.started)

        // 父回合正忙时派发后台子代理；子代理 0.3 秒后完成，通知应当入队。
        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Busy drain",
            conversationID: parentID,
            extraArguments: ["run_in_background": true]
        )
        #expect(result.isError == false)
        let record = try #require(await registry.tasks(forConversationID: parentID).first)

        let finishDeadline = Date().addingTimeInterval(10)
        var childFinished = false
        while Date() < finishDeadline {
            if let snapshot = await registry.task(for: record.id), snapshot.status != .running {
                childFinished = true
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(childFinished)
        // 子代理完成时父回合仍在跑：通知不得提前插入（忙时入队契约）。
        #expect(notificationMessages(messages: messages, conversationID: parentID).isEmpty)

        // 父回合结束后通知排空，且排在父回合最后一条助手消息之后。
        let notifications = try await waitForNotifications(
            messages: messages, conversationID: parentID, count: 1
        )
        let notification = try #require(notifications.first)
        #expect(notification.content.contains(conclusion))
        let parentMessages = messages.messages(for: parentID)
        let doneIndex = try #require(parentMessages.firstIndex(where: {
            $0.role == .assistant && $0.content.contains("Parent work done.")
        }))
        let notificationIndex = try #require(parentMessages.firstIndex(where: { $0.id == notification.id }))
        #expect(notificationIndex > doneIndex)

        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(notificationMessages(messages: messages, conversationID: parentID).count == 1)
    }

    @Test("停止后台子代理任务会级联取消子回合，且只通知一次")
    func stoppingBackgroundSubagentCancelsChildAndNotifiesOnce() async throws {
        let stub = ScriptedLLMManager()
        let task = "A background task that will be stopped."
        stub.scripts[task] = .text("Should never be delivered.")
        stub.delays[task] = 30
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))
        let agentLoop = try #require(kernel.resolveProvider((any AgentLoopProviding).self))
        let registry = try #require(kernel.resolveProvider(BackgroundTaskRegistry.self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Stopped task",
            conversationID: parentID,
            extraArguments: ["run_in_background": true]
        )
        #expect(result.isError == false)
        let record = try #require(await registry.tasks(forConversationID: parentID).first)

        // 等子回合真正开跑再停止，覆盖「运行中停止」路径。
        let startedDeadline = Date().addingTimeInterval(10)
        while Date() < startedDeadline {
            if stub.requests.contains(where: {
                $0.messages.last(where: { $0.role == .user })?.content == task
            }) { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let all = await conversations.fetchConversationPage(
            limit: 100, beforeUpdatedAt: nil, beforeID: nil, includingChildConversations: true
        )
        let child = try #require(all.first(where: { $0.parentConversationID == parentID }))

        #expect(await registry.stop(taskID: record.id) == true)

        let stopDeadline = Date().addingTimeInterval(10)
        while Date() < stopDeadline, agentLoop.isRunning(for: child.id) {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(agentLoop.isRunning(for: child.id) == false)
        // 子回合的 LLM 请求被取消打断，没有产出完整响应。
        #expect(stub.intervals[task]?.end == nil)
        let final = try #require(await registry.task(for: record.id))
        #expect(final.status == .stopped)

        let notifications = try await waitForNotifications(
            messages: messages, conversationID: parentID, count: 1
        )
        #expect(notifications.first?.content.contains("was stopped") == true)
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(notificationMessages(messages: messages, conversationID: parentID).count == 1)
    }

    @Test("取消父回合不得杀死后台子代理，完成后照常通知")
    func cancellingParentTurnDoesNotKillBackgroundChild() async throws {
        let stub = ScriptedLLMManager()
        let parentPrompt = "Dispatch background work then keep working."
        let task = "Background task surviving parent cancel."
        let conclusion = "Survived conclusion."
        stub.scripts[task] = .text(conclusion)
        stub.delays[task] = 2.5
        stub.delays[parentPrompt] = 1.0
        let callArguments = try JSONSerialization.data(withJSONObject: [
            "task": task,
            "description": "Surviving task",
            "run_in_background": true,
        ] as [String: Any])
        stub.scriptQueues[parentPrompt] = [
            .toolCalls([LLMToolCall(
                id: "call-bg",
                name: "run_subagent",
                arguments: String(decoding: callArguments, as: UTF8.self)
            )]),
            .text("Still working."),
        ]
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))
        let agentLoop = try #require(kernel.resolveProvider((any AgentLoopProviding).self))
        let registry = try #require(kernel.resolveProvider(BackgroundTaskRegistry.self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        messages.insertMessage(
            Message(conversationID: parentID, role: .user, content: parentPrompt),
            to: parentID
        )

        // 等第二个请求发出（委托已派发、父回合仍忙）再取消父回合。
        let secondRequestDeadline = Date().addingTimeInterval(15)
        var secondRequestSeen = false
        while Date() < secondRequestDeadline {
            let count = stub.requests.filter {
                $0.messages.last(where: { $0.role == .user })?.content == parentPrompt
            }.count
            if count >= 2 {
                secondRequestSeen = true
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(secondRequestSeen)
        agentLoop.cancelTurn(in: parentID)

        // 子回合不受父回合取消影响，跑完后通知照常送达。
        let record = try #require(await registry.tasks(forConversationID: parentID).first)
        let finishDeadline = Date().addingTimeInterval(15)
        var childFinished = false
        while Date() < finishDeadline {
            if let snapshot = await registry.task(for: record.id), snapshot.status == .completed {
                childFinished = true
                break
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(childFinished)
        #expect(stub.intervals[task]?.end != nil)

        let notifications = try await waitForNotifications(
            messages: messages, conversationID: parentID, count: 1
        )
        #expect(notifications.first?.content.contains(conclusion) == true)
    }

    // MARK: - UI 卡片（#1313 Task 6）

    @Test("同步委托在父会话插入时间线卡片，载荷指向真实子会话且不进 LLM 上下文")
    func syncDelegationInsertsTimelineCard() async throws {
        let stub = ScriptedLLMManager()
        let task = "Research the auth flow."
        stub.scripts[task] = .text("Auth uses JWT.")
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Auth research",
            conversationID: parentID
        )
        #expect(result.isError == false)

        let cards = messages.messages(for: parentID).filter {
            MessageTimelineEvent.isSubagentDelegation($0)
        }
        #expect(cards.count == 1)
        let card = try #require(cards.first)
        let payload = try #require(SubagentTimeline.decodePayload(from: card.metadata))
        #expect(payload.label == "Auth research")
        #expect(!payload.jobID.isEmpty)

        let all = await conversations.fetchConversationPage(
            limit: 100, beforeUpdatedAt: nil, beforeID: nil, includingChildConversations: true
        )
        let child = try #require(all.first(where: { $0.parentConversationID == parentID }))
        #expect(payload.childConversationID == child.id)

        // 卡片是界面产物：LLM 上下文构造器据 isTimelineEvent 将其排除。
        #expect(MessageTimelineEvent.isTimelineEvent(card))
        #expect(card.content.contains("Auth research"))
    }

    @Test("后台委托派发即插入时间线卡片，完成后卡片仍在")
    func backgroundDelegationInsertsTimelineCard() async throws {
        let stub = ScriptedLLMManager()
        let task = "Background research task."
        let conclusion = "Background conclusion."
        stub.scripts[task] = .text(conclusion)
        stub.delays[task] = 0.5
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Background research",
            conversationID: parentID,
            extraArguments: ["run_in_background": true]
        )
        #expect(result.isError == false)

        // 立即返回时卡片已就位，载荷指向真实子会话。
        let cards = messages.messages(for: parentID).filter {
            MessageTimelineEvent.isSubagentDelegation($0)
        }
        #expect(cards.count == 1)
        let payload = try #require(SubagentTimeline.decodePayload(from: cards.first?.metadata ?? [:]))
        let all = await conversations.fetchConversationPage(
            limit: 100, beforeUpdatedAt: nil, beforeID: nil, includingChildConversations: true
        )
        let child = try #require(all.first(where: { $0.parentConversationID == parentID }))
        #expect(payload.childConversationID == child.id)

        // 等后台完成，卡片不因完成事件被重复插入或移除。
        _ = try await waitForNotifications(messages: messages, conversationID: parentID, count: 1)
        let cardsAfter = messages.messages(for: parentID).filter {
            MessageTimelineEvent.isSubagentDelegation($0)
        }
        #expect(cardsAfter.count == 1)
        #expect(cardsAfter.first?.id == cards.first?.id)
    }

    @Test("内核装配了子代理卡片渲染器，卡片消息被路由到它")
    func cardRendererIsRegisteredAndRoutes() throws {
        let kernel = try makeKernel(stub: ScriptedLLMManager())
        let rendering = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))

        let payload = SubagentTimeline.Payload(
            label: "Routing check",
            parentConversationID: UUID(),
            childConversationID: UUID(),
            jobID: "job-routing"
        )
        let message = SubagentTimeline.message(
            conversationID: UUID(), turnID: nil, payload: payload
        )
        let renderer = try #require(rendering.renderer(for: message))
        #expect(renderer.id == SubagentTimeline.rendererID)
    }

    @Test("三路并行委托各插一张卡片，载荷互不串扰")
    func threeParallelDelegationsInsertThreeCards() async throws {
        let stub = ScriptedLLMManager()
        let tasks = (1...3).map { "Card parallel task \($0)." }
        for task in tasks { stub.scripts[task] = .text("Done.") }
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let turnID = UUID()
        async let first = runSubagent(
            toolManager: toolManager, task: tasks[0], description: "Card one",
            conversationID: parentID, turnID: turnID
        )
        async let second = runSubagent(
            toolManager: toolManager, task: tasks[1], description: "Card two",
            conversationID: parentID, turnID: turnID
        )
        async let third = runSubagent(
            toolManager: toolManager, task: tasks[2], description: "Card three",
            conversationID: parentID, turnID: turnID
        )
        let results = try await [first, second, third]
        #expect(results.allSatisfy { !$0.isError })

        let cards = messages.messages(for: parentID).filter {
            MessageTimelineEvent.isSubagentDelegation($0)
        }
        #expect(cards.count == 3)
        let payloads = cards.compactMap { SubagentTimeline.decodePayload(from: $0.metadata) }
        #expect(payloads.count == 3)
        #expect(Set(payloads.map(\.childConversationID)).count == 3)
        #expect(Set(payloads.map(\.jobID)).count == 3)
        #expect(Set(payloads.map(\.label)) == ["Card one", "Card two", "Card three"])
    }

    @Test("失败委托同样留下卡片，对应 Job 达终态")
    func failedDelegationStillInsertsCard() async throws {
        let stub = ScriptedLLMManager()
        let task = "This card task will fail."
        stub.scripts[task] = .failure("model exploded")
        let kernel = try makeKernel(stub: stub)

        let conversations = try #require(kernel.resolveProvider((any ConversationManaging).self))
        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))
        let parentID = try await conversations.createConversationAndWait(
            title: "Parent", projectPath: nil, modelID: nil, parentConversationID: nil
        )

        let result = try await runSubagent(
            toolManager: toolManager,
            task: task,
            description: "Failing card",
            conversationID: parentID
        )
        #expect(result.isError == true)

        let cards = messages.messages(for: parentID).filter {
            MessageTimelineEvent.isSubagentDelegation($0)
        }
        #expect(cards.count == 1)
        let payload = try #require(SubagentTimeline.decodePayload(from: cards.first?.metadata ?? [:]))
        let job = try #require(
            toolManager.jobs(forConversationID: parentID).first(where: { $0.id == payload.jobID })
        )
        #expect(job.status.isTerminal)
    }

    // MARK: - Helpers

    /// 后台完成通知的 metadata 标记（与 BackgroundTaskNotification 的约定一致）。
    private static let notificationMetadataKey = "lumi.backgroundNotification"

    private func notificationMessages(
        messages: any MessageManaging,
        conversationID: UUID
    ) -> [Message] {
        messages.messages(for: conversationID).filter {
            $0.metadata[Self.notificationMetadataKey] == "1"
        }
    }

    /// 轮询等待指定数量的完成通知出现。
    private func waitForNotifications(
        messages: any MessageManaging,
        conversationID: UUID,
        count: Int,
        timeout: TimeInterval = 10
    ) async throws -> [Message] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let found = notificationMessages(messages: messages, conversationID: conversationID)
            if found.count >= count { return found }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw ToolExecutionError.executionFailed(
            toolName: "run_subagent",
            reason: "background notification did not arrive within \(timeout)s"
        )
    }

    /// 执行一次 run_subagent 调用并等待工具结果。
    ///
    /// 走 `execute`——与 AgentLoop 相同的入口：内部 submit → 等 Job 终态 →
    /// 写结果缓存。裸 `submit` 后轮询 `toolCallResult` 拿不到结果：Job 通道
    /// 不写结果缓存与调用记录库，只有 execute 路径会写。
    private func runSubagent(
        toolManager: any ToolManagerProviding,
        task: String,
        description: String,
        conversationID: UUID,
        turnID: UUID = UUID(),
        extraArguments: [String: Any] = [:],
        timeout: TimeInterval = 30
    ) async throws -> ToolCallResult {
        let callID = UUID().uuidString
        var payload: [String: Any] = ["task": task, "description": description]
        for (key, value) in extraArguments { payload[key] = value }
        let arguments = try JSONSerialization.data(withJSONObject: payload)
        let call = KitAgentTool.ToolCall(
            id: callID,
            name: "run_subagent",
            arguments: String(decoding: arguments, as: UTF8.self)
        )
        // execute 内部的 Job 等待不响应 Task 取消，结构化任务组超时后仍会
        // 等它跑完才退出；用结果盒轮询，超时即可立刻失败。
        let box = ToolResultBox()
        Task { @MainActor in
            box.result = await toolManager.execute(call, conversationID: conversationID, turnID: turnID)
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let result = box.result { return result }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw ToolExecutionError.executionFailed(
            toolName: "run_subagent",
            reason: "tool job did not finish within \(timeout)s"
        )
    }

    /// 造一个注入了脚本化 LLM 的真实内核。
    private func makeKernel(stub: ScriptedLLMManager) throws -> KernelCoreContainer {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SubagentE2ETests-\(UUID().uuidString)", isDirectory: true)
        let providerFactory = DefaultProviderFactory(dataRootDirectory: root)
        return try KernelFactory.makeKernel(
            providerFactory: providerFactory,
            pluginFactory: DefaultPluginFactory(),
            additionalPlugins: [StubLLMInstallerPlugin(stub: stub)]
        )
    }
}

// MARK: - Scripted LLM

/// 跨 Task 传递工具结果的盒子；读写都在 MainActor 上，无需额外同步。
@MainActor
private final class ToolResultBox {
    var result: ToolCallResult?
}

/// 按「最后一条用户消息文本」路由响应的 LLM 替身。
///
/// 子会话 ID 在工具内部才创建，测试无法预知；用任务文本做键可以
/// 精确命中子回合的请求，其余请求（标题生成等）落到默认响应。
@MainActor
private final class ScriptedLLMManager: LLMManaging, LLMStreamingProviding, @unchecked Sendable {
    enum Script {
        case text(String)
        case failure(String)
        case toolCalls([LLMToolCall])
    }

    var scripts: [String: Script] = [:]
    /// 按任务文本排队的多段脚本（FIFO）：驱动「工具调用 → 工具结果 → 收尾」
    /// 的多轮父回合；队列耗尽后回落到 scripts。
    var scriptQueues: [String: [Script]] = [:]
    /// 按任务文本注入响应延迟，用于并发重叠与取消路径的测试。
    var delays: [String: TimeInterval] = [:]
    /// 每个任务请求的执行区间；被取消的请求只有 start 没有 end。
    private(set) var intervals: [String: (start: Date, end: Date?)] = [:]
    private(set) var requests: [LLMRequest] = []

    var providerID: String { "stub-provider" }
    var providerInfo: LLMProviderInfo {
        LLMProviderInfo(
            id: providerID,
            displayName: "Stub",
            defaultModel: "stub-model",
            models: [LLMModelInfo(id: "stub-model")],
            isLocal: true
        )
    }
    var selectedProviderID: String? { providerID }
    var selectedModel: String? { "stub-model" }
    var providerCount: Int { 1 }

    func allProviders() -> [any SuperLLMProvider] { [self] }
    func provider(id: String) -> (any SuperLLMProvider)? { id == providerID ? self : nil }
    func register(_ provider: any SuperLLMProvider) throws {}
    func unregister(id: String) {}
    func models(for providerID: String) -> [String] { ["stub-model"] }
    func select(providerID: String, model: String?, reason: ModelSelectionReason) {}

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        try await respond(to: request)
    }

    func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        let response = try await respond(to: request)
        await onChunk(LLMStreamChunk(content: response.content))
        await onChunk(LLMStreamChunk(isDone: true))
        return response
    }

    private func respond(to request: LLMRequest) async throws -> LLMResponse {
        requests.append(request)
        let task = request.messages.last(where: { $0.role == .user })?.content ?? ""
        intervals[task] = (start: Date(), end: nil)
        if let delay = delays[task] {
            // Task.sleep 响应取消：cancelTurn 取消回合 Task 时这里立刻抛出，
            // 与真实 provider 的流式请求被取消的行为一致。
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        let script: Script
        if var queue = scriptQueues[task], !queue.isEmpty {
            script = queue.removeFirst()
            scriptQueues[task] = queue
        } else {
            script = scripts[task] ?? .text("ok")
        }
        intervals[task] = (start: intervals[task]?.start ?? Date(), end: Date())
        switch script {
        case .text(let text):
            return LLMResponse(content: text, model: request.model)
        case .failure(let reason):
            throw ScriptedLLMError(reason: reason)
        case .toolCalls(let calls):
            return LLMResponse(content: "", model: request.model, toolCalls: calls)
        }
    }
}

private struct ScriptedLLMError: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
}

/// 把父回合撑住一段时间的测试工具：忙时排空路径需要「子代理完成时
/// 父回合仍在跑」的窗口。
private final class SlowTestTool: SuperAgentTool, @unchecked Sendable {
    let name = "test_slow_tool"
    private let duration: TimeInterval
    private let lock = NSLock()
    private var startedFlag = false

    var started: Bool {
        lock.lock()
        defer { lock.unlock() }
        return startedFlag
    }

    init(duration: TimeInterval) {
        self.duration = duration
    }

    var executionCapability: ToolExecutionCapability { .serialSideEffect }
    func description(for language: LanguagePreference) -> String { "Test slow tool" }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object"] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        lock.lock()
        startedFlag = true
        lock.unlock()
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        return "slow done"
    }
}

/// 在 PluginAgentLoop（order 8）启动前把内核的 LLMManaging 换成替身。
///
/// 只靠 order 7、**不声明依赖**：内核启动是分批 Kahn——第一轮按 order
/// 启动所有无依赖插件（llm-manager 5 → 本插件 7 → agent-loop 8）。
/// 一旦声明对 llm-manager 的依赖，本插件会被推迟到第二轮，反而晚于
/// agent-loop 的 LLMManaging 快照，替身就装不上了。
@MainActor
private final class StubLLMInstallerPlugin: SuperPlugin {
    let id = "com.coffic.lumi.tests.stub-llm-installer"
    let order = 7
    let metadata = PluginMetadata(
        id: "com.coffic.lumi.tests.stub-llm-installer",
        name: "Stub LLM Installer",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    private let stub: ScriptedLLMManager

    init(stub: ScriptedLLMManager) {
        self.stub = stub
    }

    func onBoot(kernel: KernelCoreContainer) throws {
        kernel.unregisterProvider((any LLMManaging).self)
        try kernel.registerProvider((any LLMManaging).self, stub)
    }
}