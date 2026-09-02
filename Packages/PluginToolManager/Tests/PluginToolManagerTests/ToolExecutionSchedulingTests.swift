import Foundation
import KitAgentTool
import ProviderToolManager
import Testing
@testable import PluginToolManager

private actor SchedulingProbe {
    private(set) var activeCount = 0
    private(set) var maximumActiveCount = 0
    private(set) var startOrder: [String] = []

    func started(_ name: String) {
        activeCount += 1
        maximumActiveCount = max(maximumActiveCount, activeCount)
        startOrder.append(name)
    }

    func finished() {
        activeCount -= 1
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
            await probe.finished()
            throw error
        }
        await probe.finished()
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
        await probe.finished()
        return name
    }
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
    _ = manager.submit(
        calls,
        policy: .autoExecute,
        conversationID: conversationID,
        turnID: turnID
    )

    for call in calls {
        _ = await manager.waitForJobResult(jobID: call.id)
    }

    let duration = Date().timeIntervalSince(startedAt)
    #expect(duration < 0.65)
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
    _ = manager.submit(
        calls,
        policy: .autoExecute,
        conversationID: UUID(),
        turnID: UUID()
    )
    for call in calls {
        _ = await manager.waitForJobResult(jobID: call.id)
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
    _ = manager.submit(calls, policy: .autoExecute, conversationID: conversationID, turnID: turnID)
    for call in calls {
        _ = await manager.waitForJobResult(jobID: call.id)
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
    _ = manager.submit(
        [calls[0]],
        policy: .autoExecute,
        conversationID: UUID(),
        turnID: UUID()
    )
    _ = manager.submit(
        [calls[1]],
        policy: .autoExecute,
        conversationID: UUID(),
        turnID: UUID()
    )
    for call in calls {
        _ = await manager.waitForJobResult(jobID: call.id)
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
    _ = manager.submit(calls, policy: .autoExecute, conversationID: scope, turnID: UUID())
    for call in calls {
        _ = await manager.waitForJobResult(jobID: call.id)
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
