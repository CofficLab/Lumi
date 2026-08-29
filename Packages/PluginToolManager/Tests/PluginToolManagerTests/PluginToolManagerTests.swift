import KernelCore
import KitAgentTool
import ProviderToolManager
import Testing
@testable import PluginToolManager

private struct CountingTool: SuperAgentTool, @unchecked Sendable {
    let name: String
    let risk: CommandRiskLevel
    let counter: Counter

    final class Counter {
        var value = 0
    }

    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { risk }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        counter.value += 1
        return name
    }
}

@MainActor
@Test func toolManagerBatchStopsAtApproval() async {
    let manager = ToolManager()
    let laterCounter = CountingTool.Counter()
    manager.add(CountingTool(name: "risky", risk: .high, counter: .init()), pluginID: "test")
    manager.add(CountingTool(name: "later", risk: .low, counter: laterCounter), pluginID: "test")

    let results = await manager.executeBatch(
        [
            ToolCall(id: "risky-1", name: "risky", arguments: "{}"),
            ToolCall(id: "later-1", name: "later", arguments: "{}")
        ],
        policy: .requireApprovalForHighRisk,
        conversationID: UUID(),
        turnID: UUID()
    )

    #expect(results.count == 1)
    #expect(laterCounter.value == 0)
}

@MainActor
@Test func unknownToolSkipsAuthorizationAndReturnsNotFoundResult() async {
    let manager = ToolManager()
    let call = ToolCall(id: "unknown-1", name: "git_reset", arguments: "{}")

    #expect(manager.authorizationDecision(for: call, conversationID: UUID()) == .autoApproved)

    let result = await manager.executeBatch(
        [call],
        policy: .requireApprovalForHighRisk,
        conversationID: UUID(),
        turnID: nil
    )

    guard case let .executed(executionResult) = result.first else {
        Issue.record("Unknown tools should be sent to execution instead of awaiting approval")
        return
    }
    #expect(executionResult.isError)
    #expect(executionResult.content == "Tool not found: git_reset")
}

@MainActor
@Test func toolManagerPluginReplacesFallbackAndRegistersBuiltinTools() throws {
    let kernel = KernelCoreContainer()
    try kernel.registerProvider((any ToolManagerProviding).self, DefaultToolManagerProviding())

    let plugin = PluginToolManager()
    try plugin.onBoot(kernel: kernel)

    let manager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
    #expect(manager is ToolManager)
    #expect(!manager.allTools().isEmpty)
    #expect(manager.tool(named: "read_file") != nil)
}

@MainActor
@Test func shellToolUsesTheCurrentWorkspaceRoot() async throws {
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    let result = try await tool.execute(arguments: [
        "command": ToolArgument("pwd"),
    ])

    #expect(
        URL(fileURLWithPath: result).standardizedFileURL.path
            == URL(fileURLWithPath: "/tmp").standardizedFileURL.path
    )
}

@MainActor
@Test func globToolUsesTheCurrentWorkspaceRootWhenPathIsOmitted() async throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let tool = GlobTool(workspaceRootProvider: { packageRoot.path })
    let result = try await tool.execute(arguments: [
        "pattern": ToolArgument("Package.swift"),
    ])

    #expect(result == "Package.swift")
}

@MainActor
@Test func toolManagerEventManagerDispatchesAndCancelsObservers() async {
    let manager = ToolManager()
    var eventCount = 0
    let handle = manager.addToolManagerObserver { _ in
        eventCount += 1
    }

    _ = await manager.executeBatch(
        [],
        policy: .autoExecute,
        conversationID: UUID(),
        turnID: nil
    )
    #expect(eventCount == 1)

    handle.cancel()

    _ = await manager.executeBatch(
        [],
        policy: .autoExecute,
        conversationID: UUID(),
        turnID: nil
    )
    #expect(eventCount == 1)
}
