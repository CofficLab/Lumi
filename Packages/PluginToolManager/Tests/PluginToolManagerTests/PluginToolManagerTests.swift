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

private struct ShellOutputEvent: Sendable {
    let stream: ToolExecutionOutputStream
    let text: String
}

private actor ShellExecutionState {
    private(set) var finished = false

    func markFinished() {
        finished = true
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
@Test func authorizedToolReusesExistingResultInsteadOfExecutingAgain() async {
    let manager = ToolManager()
    let counter = CountingTool.Counter()
    manager.add(CountingTool(name: "write_once", risk: .high, counter: counter), pluginID: "test")
    let conversationID = UUID()
    let call = ToolCall(id: "write-once-1", name: "write_once", arguments: "{}")

    let first = await manager.executeAuthorized(call, conversationID: conversationID, turnID: UUID())
    let second = await manager.executeAuthorized(call, conversationID: conversationID, turnID: UUID())

    #expect(first.content == "write_once")
    #expect(second == first)
    #expect(counter.value == 1)
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
@Test func shellToolStreamsOutputBeforeCommandCompletes() async throws {
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    let (stream, continuation) = AsyncStream<ShellOutputEvent>.makeStream()
    var iterator = stream.makeAsyncIterator()
    let state = ShellExecutionState()
    let context = ToolExecutionContext(
        jobID: "shell-stream-1",
        conversationID: UUID(),
        reportOutput: { stream, text in
            continuation.yield(ShellOutputEvent(stream: stream, text: text))
        }
    )

    let execution = Task {
        let result = try await tool.executeResult(
            context: context,
            arguments: ["command": ToolArgument("printf 'first\\n'; sleep 0.5; printf 'second\\n' >&2")]
        )
        await state.markFinished()
        return result
    }

    let first = try #require(await iterator.next())
    #expect(first.stream == .stdout)
    #expect(first.text.contains("first"))
    try await Task.sleep(nanoseconds: 100_000_000)
    #expect(await state.finished == false)

    let result = try await execution.value
    continuation.finish()
    var events = [first]
    while let event = await iterator.next() {
        events.append(event)
    }

    #expect(events.contains { $0.stream == .stderr && $0.text.contains("second") })
    #expect(result.content.contains("second"))
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
@Test func listDirectoryToolUsesTheCurrentWorkspaceRootWhenPathIsOmitted() async throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let tool = ListDirectoryTool(workspaceRootProvider: { packageRoot.path })
    let result = try await tool.execute(arguments: [:])

    #expect(result.split(separator: "\n").contains("Package.swift"))
}

@MainActor
@Test func readFileToolResolvesRelativePathFromTheCurrentWorkspaceRoot() async throws {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let tool = ReadFileTool(workspaceRootProvider: { packageRoot.path })
    let result = try await tool.execute(arguments: [
        "path": ToolArgument("Package.swift"),
        "limit": ToolArgument(20),
    ])

    #expect(result.contains("name: \"PluginToolManager\""))
}

@MainActor
@Test func writeFileToolResolvesRelativePathFromTheCurrentWorkspaceRoot() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-write-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let tool = WriteFileTool(workspaceRootProvider: { root.path })
    _ = try await tool.execute(arguments: [
        "path": ToolArgument("notes/todo.txt"),
        "content": ToolArgument("hello workspace"),
    ])

    let written = try String(
        contentsOf: root.appendingPathComponent("notes/todo.txt"),
        encoding: .utf8
    )
    #expect(written == "hello workspace")
}

@MainActor
@Test func editFileToolResolvesRelativePathFromTheCurrentWorkspaceRoot() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-edit-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let fileURL = root.appendingPathComponent("notes/todo.txt")
    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "before".write(to: fileURL, atomically: true, encoding: .utf8)

    let tool = EditFileTool(workspaceRootProvider: { root.path })
    _ = try await tool.execute(arguments: [
        "file_path": ToolArgument("notes/todo.txt"),
        "old_string": ToolArgument("before"),
        "new_string": ToolArgument("after"),
    ])

    let edited = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(edited == "after")
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
