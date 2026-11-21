import Foundation
import KitAgentTool
import KitMCP
import ProviderToolManager
import Testing
@testable import PluginMCP

/// stdio 子进程意外退出后 Manager 状态与工具注册同步回归（#473）。
///
/// 此前意外退出只改会话内部标志：Manager 继续发布 Running，失效工具
/// 保持注册，LLM 仍会调用必然失败的工具。
@Suite("MCP 连接管理器意外退出", .serialized)
@MainActor
struct MCPConnectionTerminationTests {

    @Test("子进程意外退出：立即撤回工具、断开会话并置 error（回归 #473）")
    func unexpectedExitWithdrawsToolsAndMarksError() async throws {
        let (manager, toolManager, session, serverID) = try await makeConnectedManager()
        #expect(manager.state(for: serverID) == .connected)
        let registeredNames = Set(manager.registeredTools[serverID]?.map(\.name) ?? [])
        #expect(!registeredNames.isEmpty, "连接成功后应注册工具")
        #expect(toolManager.addedIDs == registeredNames)

        await session.emitUnexpectedExit(9)

        let deadline = Date().addingTimeInterval(2)
        while manager.state(for: serverID) == .connected, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(manager.state(for: serverID) == .error("服务器进程已退出（码 9）"))
        #expect(manager.registeredTools[serverID] == nil, "失效工具必须撤回")
        #expect(toolManager.removedIDs == registeredNames)
        #expect(await session.disconnectCount == 1, "意外退出后应清理会话")
    }

    @Test("显式 disconnect 后到达的退出事件不再改写状态")
    func lateEventAfterExplicitDisconnectDoesNotOverwriteState() async throws {
        let (manager, toolManager, session, serverID) = try await makeConnectedManager()
        let registeredNames = Set(manager.registeredTools[serverID]?.map(\.name) ?? [])

        await manager.disconnect(serverID: serverID)
        #expect(manager.state(for: serverID) == .disconnected)
        #expect(toolManager.removedIDs == registeredNames, "显式 disconnect 撤回工具")

        await session.emitUnexpectedExit(9)
        // 给已取消的 watcher 一轮调度机会，确认不会误处理迟到事件。
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(manager.state(for: serverID) == .disconnected)
        #expect(manager.registeredTools[serverID] == nil)
        #expect(toolManager.removedIDs == registeredNames, "迟到事件不得重复处理")
        #expect(await session.disconnectCount == 1, "只有显式 disconnect 清理会话")
    }

    // MARK: - Harness

    /// 构造注册了单个 stub 服务器的 manager 并完成连接。
    private func makeConnectedManager() async throws -> (
        manager: MCPConnectionManager,
        toolManager: RecordingToolManager,
        session: TerminatableSession,
        serverID: String
    ) {
        let root = MCPTestDoubles.makeTemporaryDirectory("termination")
        let registry = MCPServerRegistry(directory: root)
        let config = try registry.addServer(MCPServerConfig(name: "Stub", command: "/bin/echo"))
        let toolManager = RecordingToolManager()
        let session = TerminatableSession(config: config)
        let manager = MCPConnectionManager(
            registry: registry,
            toolManager: toolManager,
            pluginID: "test-plugin",
            sessionFactory: { _ in session }
        )
        await manager.connect(serverID: config.id)
        return (manager, toolManager, session, config.id)
    }
}

/// 记录注册/移除的 ToolManager 替身。
@MainActor
private final class RecordingToolManager: ToolManagerProviding {
    private(set) var addedIDs: Set<String> = []
    private(set) var removedIDs: Set<String> = []

    @discardableResult
    func addToolManagerObserver(
        _ callback: @escaping (ToolManagerEvent) -> Void
    ) -> any ToolManagerObserverHandle {
        NoopToolManagerObserverHandle()
    }

    @discardableResult
    func addToolJobObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle {
        NoopToolJobObserverHandle()
    }

    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {
        addedIDs.insert(tool.name)
    }
    func remove(id: String) {
        removedIDs.insert(id)
    }
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: ToolCall) -> String? { nil }
    func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? { nil }
    func execute(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        ToolCallResult(content: "unused")
    }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
    func deleteToolCalls(for conversationID: UUID) async {}
}

@MainActor
private final class NoopToolManagerObserverHandle: ToolManagerObserverHandle {
    func cancel() {}
}

@MainActor
private final class NoopToolJobObserverHandle: ToolJobObserverHandle {
    func cancel() {}
}

/// 可触发意外退出的会话替身：connect 成功、listTools 返回一个工具，
/// 测试经 `emitUnexpectedExit` 模拟子进程退出。
private actor TerminatableSession: MCPServerServing {
    let config: MCPServerConfig
    private(set) var isConnected = false
    private(set) var disconnectCount = 0
    private let events: AsyncStream<Int32>
    private var continuation: AsyncStream<Int32>.Continuation?

    init(config: MCPServerConfig) {
        self.config = config
        let (stream, continuation) = AsyncStream.makeStream(of: Int32.self)
        self.events = stream
        self.continuation = continuation
    }

    func connect() async throws {
        isConnected = true
    }

    func disconnect() async {
        disconnectCount += 1
        isConnected = false
        continuation?.finish()
    }

    func listTools() async throws -> [MCPToolDescriptor] {
        [MCPToolDescriptor(name: "echo", description: "Echo")]
    }

    func callTool(name: String, arguments: [String: MCPJSONValue]) async throws -> MCPCallResult {
        MCPCallResult(text: "unused")
    }

    func unexpectedTerminationEvents() async -> AsyncStream<Int32>? {
        events
    }

    func emitUnexpectedExit(_ code: Int32) {
        continuation?.yield(code)
        continuation?.finish()
    }
}
