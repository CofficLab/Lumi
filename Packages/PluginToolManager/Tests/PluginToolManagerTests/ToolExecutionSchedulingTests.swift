import Foundation
import KitAgentTool
import ProviderConversation
import ProviderToolManager
import Testing
@testable import PluginToolManager

private actor SchedulingProbe {
    private(set) var activeCount = 0
    private(set) var maximumActiveCount = 0
    private(set) var startOrder: [String] = []
    private(set) var finishOrder: [String] = []

    func started(_ name: String) {
        activeCount += 1
        maximumActiveCount = max(maximumActiveCount, activeCount)
        startOrder.append(name)
    }

    func finished(_ name: String) {
        activeCount -= 1
        finishOrder.append(name)
    }
}

private struct SchedulingTool: SuperAgentTool, @unchecked Sendable {
    let name: String
    let executionCapability: ToolExecutionCapability
    let delayNanoseconds: UInt64
    let probe: SchedulingProbe

    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        await probe.started(name)
        do {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        } catch {
            await probe.finished(name)
            throw error
        }
        await probe.finished(name)
        return name
    }
}

private struct DefaultCapabilityTool: SuperAgentTool, @unchecked Sendable {
    let name: String
    let delayNanoseconds: UInt64
    let probe: SchedulingProbe

    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        await probe.started(name)
        try await Task.sleep(nanoseconds: delayNanoseconds)
        await probe.finished(name)
        return name
    }
}

private struct ConversationProjectPathTool: SuperAgentTool {
    let name = "conversation_project_path"

    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .safe }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }
    func execute(arguments: [String: ToolArgument]) async throws -> String { "legacy path" }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        ToolCallResult(content: await context.conversationProjectPath() ?? "no project")
    }
}

@MainActor
@Test("工具上下文使用发起对话绑定的项目，不受当前选中对话影响")
func toolContextResolvesProjectForOwningConversation() async throws {
    let conversations = DefaultConversationManager()
    let firstConversationID = try conversations.createConversation(
        title: "Project A",
        projectPath: "/tmp/project-a",
        providerID: nil,
        modelName: nil
    )
    let secondConversationID = try conversations.createConversation(
        title: "Project B",
        projectPath: "/tmp/project-b",
        providerID: nil,
        modelName: nil
    )
    #expect(conversations.selectedConversationID == secondConversationID)

    let manager = ToolManager()
    manager.conversationManager = conversations
    manager.add(ConversationProjectPathTool(), pluginID: "test")
    let job = try #require(manager.submit(
        [ToolCall(id: "project-path", name: "conversation_project_path", arguments: "{}")],
        policy: .autoExecute,
        conversationID: firstConversationID,
        turnID: UUID()
    ).first)

    let result = await manager.waitForJobResult(jobID: job.id)
    #expect(result?.content == "/tmp/project-a")
}

@MainActor
@Test("只读工具在同一回合并行执行，且不超过四个")
func readOnlyJobsRunInParallelWithPerTurnLimit() async {
    let manager = ToolManager()
    let probe = SchedulingProbe()
    let tools = (1...5).map { index in
        SchedulingTool(
            name: "read-\(index)",
            executionCapability: .parallelReadOnly,
            delayNanoseconds: 250_000_000,
            probe: probe
        )
    }
    for tool in tools {
        manager.add(tool, pluginID: "test")
    }

    let conversationID = UUID()
    let turnID = UUID()
    let calls = tools.map { ToolCall(id: $0.name, name: $0.name, arguments: "{}") }
    let startedAt = Date()
    let jobs = manager.submit(
        calls,
        policy: .autoExecute,
        conversationID: conversationID,
        turnID: turnID
    )

    for job in jobs {
        _ = await manager.waitForJobResult(jobID: job.id)
    }

    let duration = Date().timeIntervalSince(startedAt)
    // 上限给到 1.0s。
    //
    // - Important: 这条断言要区分的是「**并行**」与「**串行**」：
    //   5 个工具各延迟 250ms，串行需 1.25s，并行（上限 4）需 0.5s。
    //   原先的 0.65s 只比并行下界多 150ms 余量，高负载下（CI 上多个包
    //   同时跑）调度延迟就能吃掉它 → **偶发**失败。
    //
    //   1.0s 仍远小于串行的 1.25s，并行/串行的区分度保持不变。
    //   真正的「并发上限是 4」由下一条断言（maximumActiveCount）负责。
    #expect(duration < 1.0)
    #expect(await probe.maximumActiveCount == 4)
}

@MainActor
@Test("副作用工具会阻断后续只读工具")
func sideEffectJobsCreateAnOrderingBarrier() async {
    let manager = ToolManager()
    let probe = SchedulingProbe()
    let tools = [
        SchedulingTool(
            name: "read-before-write",
            executionCapability: .parallelReadOnly,
            delayNanoseconds: 120_000_000,
            probe: probe
        ),
        SchedulingTool(
            name: "write-barrier",
            executionCapability: .serialSideEffect,
            delayNanoseconds: 20_000_000,
            probe: probe
        ),
        SchedulingTool(
            name: "read-after-write",
            executionCapability: .parallelReadOnly,
            delayNanoseconds: 20_000_000,
            probe: probe
        )
    ]
    for tool in tools {
        manager.add(tool, pluginID: "test")
    }

    let calls = tools.map { ToolCall(id: $0.name, name: $0.name, arguments: "{}") }
    let jobs = manager.submit(
        calls,
        policy: .autoExecute,
        conversationID: UUID(),
        turnID: UUID()
    )
    for job in jobs {
        _ = await manager.waitForJobResult(jobID: job.id)
    }

    #expect(await probe.startOrder == ["read-before-write", "write-barrier", "read-after-write"])
}

@MainActor
@Test("副作用工具按提交顺序串行执行")
func sideEffectJobsRemainOrdered() async {
    let manager = ToolManager()
    let probe = SchedulingProbe()
    let tools = (1...3).map { index in
        SchedulingTool(
            name: "write-\(index)",
            executionCapability: .serialSideEffect,
            delayNanoseconds: 80_000_000,
            probe: probe
        )
    }
    for tool in tools {
        manager.add(tool, pluginID: "test")
    }

    let calls = tools.map { ToolCall(id: $0.name, name: $0.name, arguments: "{}") }
    let conversationID = UUID()
    let turnID = UUID()
    let jobs = manager.submit(calls, policy: .autoExecute, conversationID: conversationID, turnID: turnID)
    for job in jobs {
        _ = await manager.waitForJobResult(jobID: job.id)
    }

    #expect(await probe.maximumActiveCount == 1)
    #expect(await probe.startOrder == ["write-1", "write-2", "write-3"])
}

@MainActor
@Test("不同会话之间不互相阻塞")
func differentConversationsCanRunInParallel() async {
    let manager = ToolManager()
    let probe = SchedulingProbe()
    let first = SchedulingTool(
        name: "conversation-a",
        executionCapability: .serialSideEffect,
        delayNanoseconds: 180_000_000,
        probe: probe
    )
    let second = SchedulingTool(
        name: "conversation-b",
        executionCapability: .serialSideEffect,
        delayNanoseconds: 180_000_000,
        probe: probe
    )
    manager.add(first, pluginID: "test")
    manager.add(second, pluginID: "test")

    let calls = [
        ToolCall(id: "conversation-a", name: first.name, arguments: "{}"),
        ToolCall(id: "conversation-b", name: second.name, arguments: "{}")
    ]
    let startedAt = Date()
    let firstJobs = manager.submit(
        [calls[0]],
        policy: .autoExecute,
        conversationID: UUID(),
        turnID: UUID()
    )
    let secondJobs = manager.submit(
        [calls[1]],
        policy: .autoExecute,
        conversationID: UUID(),
        turnID: UUID()
    )
    for job in firstJobs + secondJobs {
        _ = await manager.waitForJobResult(jobID: job.id)
    }

    #expect(Date().timeIntervalSince(startedAt) < 0.35)
    #expect(await probe.maximumActiveCount == 2)
}

@MainActor
@Test("未声明能力的自定义工具默认串行")
func customToolsDefaultToSerialSideEffect() async {
    let manager = ToolManager()
    let probe = SchedulingProbe()
    let tools = [
        DefaultCapabilityTool(name: "custom-1", delayNanoseconds: 70_000_000, probe: probe),
        DefaultCapabilityTool(name: "custom-2", delayNanoseconds: 70_000_000, probe: probe)
    ]
    for tool in tools {
        manager.add(tool, pluginID: "test")
    }

    let calls = tools.map { ToolCall(id: $0.name, name: $0.name, arguments: "{}") }
    let scope = UUID()
    let jobs = manager.submit(calls, policy: .autoExecute, conversationID: scope, turnID: UUID())
    for job in jobs {
        _ = await manager.waitForJobResult(jobID: job.id)
    }

    #expect(await probe.maximumActiveCount == 1)
}

@MainActor
@Test("内置工具声明了正确的调度能力")
func builtinToolsDeclareSchedulingCapabilities() {
    let manager = ToolManager()
    manager.registerBuiltinTools()
    let tools = Dictionary(uniqueKeysWithValues: manager.allTools().map { ($0.name, $0) })

    #expect(tools["read_file"]?.executionCapability == .parallelReadOnly)
    #expect(tools["read_image"]?.executionCapability == .parallelReadOnly)
    #expect(tools["ls"]?.executionCapability == .parallelReadOnly)
    #expect(tools["glob"]?.executionCapability == .parallelReadOnly)
    #expect(tools["write_file"]?.executionCapability == .serialSideEffect)
    #expect(tools["edit_file"]?.executionCapability == .serialSideEffect)
    #expect(tools["run_command"]?.executionCapability == .serialSideEffect)
}

// MARK: - #1312 Task 1：混合批次与取消路径语义固化

private func waitForActiveCount(_ probe: SchedulingProbe, atLeast target: Int) async throws {
    for _ in 0..<200 {
        if await probe.activeCount >= target { return }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

@MainActor
@Test("混合批次：前序读并行，副作用屏障等齐前序读，后续读在屏障后并行且不超上限")
func mixedBatchKeepsReadsOverlappingAndBarrierOrdered() async throws {
    let manager = ToolManager()
    let probe = SchedulingProbe()
    let tools = [
        SchedulingTool(name: "read-1", executionCapability: .parallelReadOnly, delayNanoseconds: 150_000_000, probe: probe),
        SchedulingTool(name: "read-2", executionCapability: .parallelReadOnly, delayNanoseconds: 150_000_000, probe: probe),
        SchedulingTool(name: "write-barrier", executionCapability: .serialSideEffect, delayNanoseconds: 100_000_000, probe: probe),
        SchedulingTool(name: "read-3", executionCapability: .parallelReadOnly, delayNanoseconds: 100_000_000, probe: probe),
        SchedulingTool(name: "read-4", executionCapability: .parallelReadOnly, delayNanoseconds: 100_000_000, probe: probe),
        SchedulingTool(name: "read-5", executionCapability: .parallelReadOnly, delayNanoseconds: 100_000_000, probe: probe),
        SchedulingTool(name: "read-6", executionCapability: .parallelReadOnly, delayNanoseconds: 100_000_000, probe: probe),
        SchedulingTool(name: "read-7", executionCapability: .parallelReadOnly, delayNanoseconds: 100_000_000, probe: probe),
    ]
    for tool in tools { manager.add(tool, pluginID: "test") }

    let calls = tools.map { ToolCall(id: $0.name, name: $0.name, arguments: "{}") }
    let jobs = manager.submit(calls, policy: .autoExecute, conversationID: UUID(), turnID: UUID())
    for job in jobs { _ = await manager.waitForJobResult(jobID: job.id) }

    let startOrder = await probe.startOrder
    let finishOrder = await probe.finishOrder
    try #require(startOrder.count == 8)
    #expect(Set(startOrder.prefix(2)) == ["read-1", "read-2"])
    #expect(startOrder[2] == "write-barrier")
    #expect(Set(startOrder.suffix(5)) == ["read-3", "read-4", "read-5", "read-6", "read-7"])
    // 屏障必须等齐两个前序读结束才启动：读不可越过屏障，屏障也不可越过读。
    let barrierFinish = try #require(finishOrder.firstIndex(of: "write-barrier"))
    let read1Finish = try #require(finishOrder.firstIndex(of: "read-1"))
    let read2Finish = try #require(finishOrder.firstIndex(of: "read-2"))
    #expect(read1Finish < barrierFinish)
    #expect(read2Finish < barrierFinish)
    // 屏障后的五个读真实并行，且并发不超过上限 4。
    #expect(await probe.maximumActiveCount == 4)
}

@MainActor
@Test("取消一个并行读不影响同批其他读")
func cancellingOneParallelReadDoesNotCancelSiblings() async throws {
    let manager = ToolManager()
    let probe = SchedulingProbe()
    let tools = (0..<3).map { index in
        SchedulingTool(
            name: "read-\(index)",
            executionCapability: .parallelReadOnly,
            delayNanoseconds: 300_000_000,
            probe: probe
        )
    }
    for tool in tools { manager.add(tool, pluginID: "test") }

    let calls = tools.map { ToolCall(id: $0.name, name: $0.name, arguments: "{}") }
    let jobs = manager.submit(calls, policy: .autoExecute, conversationID: UUID(), turnID: UUID())

    try await waitForActiveCount(probe, atLeast: 3)
    #expect(await probe.activeCount == 3)
    manager.cancelJob(jobs[1].id)

    var results: [ToolCallResult?] = []
    for job in jobs {
        results.append(await manager.waitForJobResult(jobID: job.id))
    }
    #expect(results[0]?.content == "read-0")
    #expect(results[0]?.isError == false)
    #expect(results[1]?.isError == true)
    #expect(results[2]?.content == "read-2")
    #expect(results[2]?.isError == false)
    #expect(manager.job(for: jobs[0].id)?.status == .completed)
    #expect(manager.job(for: jobs[1].id)?.status == .cancelled)
    #expect(manager.job(for: jobs[2].id)?.status == .completed)
    #expect(await probe.maximumActiveCount == 3)
}

@MainActor
@Test("取消屏障后排队的读：立即终态，屏障照常完成")
func cancellingQueuedReadBehindBarrierFinishesImmediately() async throws {
    let manager = ToolManager()
    let probe = SchedulingProbe()
    let barrier = SchedulingTool(
        name: "write-barrier",
        executionCapability: .serialSideEffect,
        delayNanoseconds: 200_000_000,
        probe: probe
    )
    let queuedRead = SchedulingTool(
        name: "read-queued",
        executionCapability: .parallelReadOnly,
        delayNanoseconds: 50_000_000,
        probe: probe
    )
    manager.add(barrier, pluginID: "test")
    manager.add(queuedRead, pluginID: "test")

    let jobs = manager.submit(
        [
            ToolCall(id: "write-barrier", name: "write-barrier", arguments: "{}"),
            ToolCall(id: "read-queued", name: "read-queued", arguments: "{}"),
        ],
        policy: .autoExecute,
        conversationID: UUID(),
        turnID: UUID()
    )
    // 读被更早的副作用屏障挡住，提交后必然还在排队。
    #expect(manager.job(for: jobs[1].id)?.status == .queued)
    manager.cancelJob(jobs[1].id)
    #expect(manager.job(for: jobs[1].id)?.status == .cancelled)

    let barrierResult = await manager.waitForJobResult(jobID: jobs[0].id)
    let readResult = await manager.waitForJobResult(jobID: jobs[1].id)
    #expect(barrierResult?.content == "write-barrier")
    #expect(barrierResult?.isError == false)
    #expect(readResult?.isError == true)
    #expect(await probe.startOrder == ["write-barrier"])
}

@MainActor
@Test("整回合取消：每个调用都拿到终态结果，不留无结果孤儿")
func turnCancellationSettlesEveryJobWithAResult() async throws {
    let manager = ToolManager()
    let probe = SchedulingProbe()
    let tools = [
        SchedulingTool(name: "read-a", executionCapability: .parallelReadOnly, delayNanoseconds: 300_000_000, probe: probe),
        SchedulingTool(name: "read-b", executionCapability: .parallelReadOnly, delayNanoseconds: 300_000_000, probe: probe),
        SchedulingTool(name: "write-c", executionCapability: .serialSideEffect, delayNanoseconds: 300_000_000, probe: probe),
        SchedulingTool(name: "read-d", executionCapability: .parallelReadOnly, delayNanoseconds: 50_000_000, probe: probe),
    ]
    for tool in tools { manager.add(tool, pluginID: "test") }

    let calls = tools.map { ToolCall(id: $0.name, name: $0.name, arguments: "{}") }
    let turnID = UUID()
    let jobs = manager.submit(calls, policy: .autoExecute, conversationID: UUID(), turnID: turnID)

    try await waitForActiveCount(probe, atLeast: 2)
    manager.cancelJobs(forTurnID: turnID)

    for job in jobs {
        let result = await manager.waitForJobResult(jobID: job.id)
        #expect(result != nil)
        #expect(manager.job(for: job.id)?.status == .cancelled)
    }
}
