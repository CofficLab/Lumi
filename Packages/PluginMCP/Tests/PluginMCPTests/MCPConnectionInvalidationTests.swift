import Foundation
import KitAgentTool
import KitMCP
import ProviderToolManager
import Testing
@testable import PluginMCP

/// 断开/禁用对在途连接的作废回归（#401）。
///
/// 此前 connect 的 await 期间发生 disconnect 或禁用后，迟到的完成仍会
/// 注册工具并把状态改回 Connected：被禁用的服务器「死而复生」。
@Suite("MCP 在途连接作废", .serialized)
@MainActor
struct MCPConnectionInvalidationTests {

    @Test("连接建立期间断开：迟到的完成不得注册工具或改回 Connected")
    func lateConnectAfterDisconnectDoesNotRegister() async throws {
        let (manager, toolManager, sessions, serverID, _) = try await makeHarness()
        let pending = Task { await manager.connect(serverID: serverID) }
        guard await waitFor({ sessions.items.count >= 1 }) else { return }
        await sessions.items[0].waitUntilGateEntered()
        await manager.disconnect(serverID: serverID)
        await sessions.items[0].releaseGate()
        await pending.value

        #expect(manager.state(for: serverID) == .disconnected, "断开后迟到的完成不得改回 Connected")
        #expect(manager.registeredTools[serverID] == nil, "断开后不得注册工具")
        #expect(toolManager.addedIDs.isEmpty)
        #expect(await sessions.items[0].disconnectCount >= 1, "作废的旧会话应被清理")
    }

    @Test("listTools 期间断开：迟到的工具列表不得注册")
    func lateListToolsAfterDisconnectDoesNotRegister() async throws {
        let (manager, toolManager, sessions, serverID, _) = try await makeHarness(phase: .listTools)
        let pending = Task { await manager.connect(serverID: serverID) }
        guard await waitFor({ sessions.items.count >= 1 }) else { return }
        await sessions.items[0].waitUntilGateEntered()
        await manager.disconnect(serverID: serverID)
        await sessions.items[0].releaseGate()
        await pending.value

        #expect(manager.state(for: serverID) == .disconnected)
        #expect(manager.registeredTools[serverID] == nil)
        #expect(toolManager.addedIDs.isEmpty)
    }

    @Test("listTools 期间禁用：迟到的工具列表不得注册")
    func lateListToolsAfterDisableDoesNotRegister() async throws {
        let (manager, toolManager, sessions, serverID, registry) = try await makeHarness(phase: .listTools)
        let pending = Task { await manager.connect(serverID: serverID) }
        guard await waitFor({ sessions.items.count >= 1 }) else { return }
        await sessions.items[0].waitUntilGateEntered()

        guard var config = registry.server(id: serverID) else {
            Issue.record("server config missing")
            return
        }
        config.enabled = false
        try registry.updateServer(config)

        await sessions.items[0].releaseGate()
        await pending.value

        #expect(manager.state(for: serverID) != .connected, "禁用后迟到的完成不得改回 Connected")
        #expect(manager.registeredTools[serverID] == nil, "禁用后不得注册工具")
        #expect(toolManager.addedIDs.isEmpty)
    }

    @Test("断开后重连：旧会话迟到的完成不得覆盖新连接的注册")
    func staleCompletionAfterReconnectDoesNotClobberNewConnection() async throws {
        let root = MCPTestDoubles.makeTemporaryDirectory("invalidation-reconnect")
        let registry = MCPServerRegistry(directory: root)
        let config = try registry.addServer(MCPServerConfig(name: "Stub", command: "/bin/echo"))
        let toolManager = RecordingToolManager()
        var gated: GatedConnectSession?
        var callCount = 0
        let manager = MCPConnectionManager(
            registry: registry,
            toolManager: toolManager,
            pluginID: "test-plugin",
            sessionFactory: { factoryConfig in
                callCount += 1
                if callCount == 1 {
                    let session = GatedConnectSession(
                        config: factoryConfig,
                        phase: .connect,
                        toolNames: ["staleEcho"]
                    )
                    gated = session
                    return session
                }
                return GatedConnectSession(
                    config: factoryConfig,
                    phase: .none,
                    toolNames: ["echo"]
                )
            }
        )

        let pending = Task { await manager.connect(serverID: config.id) }
        guard await waitFor({ gated != nil }) else { return }
        await gated?.waitUntilGateEntered()
        await manager.disconnect(serverID: config.id)
        await manager.connect(serverID: config.id)
        await gated?.releaseGate()
        await pending.value

        #expect(manager.state(for: config.id) == .connected, "新连接应保持 Connected")
        // 工具注册名带服务器 ID 前缀（<serverID>.<name>），按后缀判定身份。
        let names = manager.registeredTools[config.id]?.map(\.name) ?? []
        #expect(names.count == 1, "只有新连接注册工具")
        #expect(names.first?.hasSuffix(".echo") == true, "新连接的 echo 应注册")
        #expect(names.contains { $0.contains("staleEcho") } == false, "旧会话的 staleEcho 不得覆盖")
        #expect(toolManager.addedIDs.count == 1 && toolManager.addedIDs.first?.hasSuffix(".echo") == true)
    }

    // MARK: - Harness

    /// 构造单个 gated 会话的 Manager；会话先挂起等待测试显式放行。
    private func makeHarness(
        phase: GatedConnectSession.Phase = .connect
    ) async throws -> (
        manager: MCPConnectionManager,
        toolManager: RecordingToolManager,
        sessions: SessionList,
        serverID: String,
        registry: MCPServerRegistry
    ) {
        let root = MCPTestDoubles.makeTemporaryDirectory("invalidation")
        let registry = MCPServerRegistry(directory: root)
        let config = try registry.addServer(MCPServerConfig(name: "Stub", command: "/bin/echo"))
        let toolManager = RecordingToolManager()
        let sessions = SessionList()
        let manager = MCPConnectionManager(
            registry: registry,
            toolManager: toolManager,
            pluginID: "test-plugin",
            sessionFactory: { factoryConfig in
                let session = GatedConnectSession(
                    config: factoryConfig,
                    phase: phase,
                    toolNames: ["echo"]
                )
                sessions.items.append(session)
                return session
            }
        )
        return (manager, toolManager, sessions, config.id, registry)
    }

    /// 轮询等待工厂创建 gated 会话；超时记失败并返回 false。
    private func waitFor(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        let ready = condition()
        #expect(ready, "gated 会话应已由工厂创建")
        return ready
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

/// 工厂创建的会话清单：引用类型，使工厂闭包内的追加对轮询可见。
@MainActor
private final class SessionList {
    var items: [GatedConnectSession] = []
}

/// 可挂起的会话替身：`phase` 指定在 connect 或 listTools 中挂起，
/// 测试经 `waitUntilGateEntered` 等待、`releaseGate` 放行。
private actor GatedConnectSession: MCPServerServing {
    enum Phase {
        case connect
        case listTools
        case none
    }

    let config: MCPServerConfig
    private(set) var isConnected = false
    private(set) var disconnectCount = 0
    private let phase: Phase
    private let toolNames: [String]
    private var gateEntered = false
    private var arrivalContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init(config: MCPServerConfig, phase: Phase, toolNames: [String]) {
        self.config = config
        self.phase = phase
        self.toolNames = toolNames
    }

    func connect() async throws {
        if phase == .connect {
            await enterGate()
        }
        isConnected = true
    }

    func disconnect() async {
        disconnectCount += 1
        isConnected = false
    }

    func listTools() async throws -> [MCPToolDescriptor] {
        if phase == .listTools {
            await enterGate()
        }
        return toolNames.map { MCPToolDescriptor(name: $0, description: $0) }
    }

    func callTool(
        name: String,
        arguments: [String: MCPJSONValue]
    ) async throws -> MCPCallResult {
        MCPCallResult(text: "unused")
    }

    func unexpectedTerminationEvents() async -> AsyncStream<Int32>? { nil }

    func waitUntilGateEntered() async {
        if gateEntered { return }
        await withCheckedContinuation { arrivalContinuation = $0 }
    }

    func releaseGate() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    private func enterGate() async {
        gateEntered = true
        arrivalContinuation?.resume()
        arrivalContinuation = nil
        await withCheckedContinuation { releaseContinuation = $0 }
    }
}
