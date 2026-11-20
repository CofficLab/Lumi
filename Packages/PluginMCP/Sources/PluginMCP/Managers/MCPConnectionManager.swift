import Foundation
import KitAgentTool
import KitMCP
import ProviderToolManager
import Combine

/// 服务器连接状态（供 UI 展示）。
public enum MCPServerConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    public var displayName: String {
        // 本地化 key（英文兜底），UI 渲染时经 MCPText 翻译。
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Running"
        case .error: return "Error"
        }
    }
}

/// MCP 会话生命周期管理：连接/断开服务器、工具注册/移除、状态发布。
///
/// 主线程隔离（UI 观察）；底层会话（`MCPServerSession` actor）跨线程安全。
@MainActor
public final class MCPConnectionManager: ObservableObject {
    /// serverID → 活跃会话。
    private var sessions: [String: any MCPServerServing] = [:]
    /// serverID → 已注册的桥接工具。
    @Published public private(set) var registeredTools: [String: [MCPToolAdapter]] = [:]
    /// serverID → 连接状态。
    @Published public private(set) var states: [String: MCPServerConnectionState] = [:]

    private let registry: MCPServerRegistry
    private weak var toolManager: (any ToolManagerProviding)?
    private let pluginID: String
    private let policy: MCPPermissionPolicy
    /// serverID → 意外退出监视任务。
    private var terminationWatchers: [String: Task<Void, Never>] = [:]
    /// serverID → 连接代次（#401）：断开/重连递增，作废在途连接的迟到完成。
    private var connectGenerations: [String: Int] = [:]
    /// 会话工厂（测试注入替身用；生产为 nil，直接构造 `MCPServerSession`）。
    private let sessionFactory: ((MCPServerConfig) -> any MCPServerServing)?

    public init(
        registry: MCPServerRegistry,
        toolManager: (any ToolManagerProviding)?,
        pluginID: String,
        policy: MCPPermissionPolicy = MCPPermissionPolicy(),
        sessionFactory: ((MCPServerConfig) -> any MCPServerServing)? = nil
    ) {
        self.registry = registry
        self.toolManager = toolManager
        self.pluginID = pluginID
        self.policy = policy
        self.sessionFactory = sessionFactory
        for server in registry.servers where !server.enabled {
            states[server.id] = .disconnected
        }
    }

    // MARK: - Lifecycle

    /// 启动 autoStart 且启用的服务器（`onBoot` 调用）。
    public func startAutoStartServers() async {
        guard registry.globalEnabled else { return }
        for server in registry.servers where server.enabled && server.autoStart {
            await connect(serverID: server.id)
        }
    }

    /// 关闭全部会话并移除全部已注册工具（`onShutdown` 调用）。
    public func shutdown() async {
        for serverID in sessions.keys {
            await disconnect(serverID: serverID)
        }
    }

    // MARK: - Connect / Disconnect

    public func connect(serverID: String) async {
        guard let config = registry.server(id: serverID) else {
            states[serverID] = .error("服务器不存在")
            return
        }
        guard config.enabled else {
            states[serverID] = .disconnected
            return
        }
        guard registry.globalEnabled else {
            states[serverID] = .disconnected
            return
        }
        guard sessions[serverID] == nil else { return } // 已在连接/已连接

        states[serverID] = .connecting
        let session = sessionFactory?(config) ?? MCPServerSession(config: config)
        sessions[serverID] = session
        connectGenerations[serverID, default: 0] &+= 1
        let generation = connectGenerations[serverID]!
        do {
            try await session.connect()
            let descriptors = try await session.listTools()
            // 等待期间服务器可能被禁用、整体关闭或断开重连（#401）：迟到的
            // 完成不得注册工具，也不得把状态改回 Connected；旧会话直接废弃。
            guard connectGenerations[serverID] == generation,
                  registry.server(id: serverID)?.enabled == true,
                  registry.globalEnabled else {
                await session.disconnect()
                return
            }
            // 精确 Xcode 规则只对本机 mcpbridge 生效；以实际命令而非服务器 id
            // 判定身份，避免 foreign 服务器的同名工具继承权限（#530）。
            let isXcodeNative = MCPPermissionPolicy.isXcodeNativeServer(
                command: config.command,
                arguments: config.arguments
            )
            let adapters = descriptors.map { descriptor in
                MCPToolAdapter(
                    serverID: serverID,
                    serverName: config.name,
                    descriptor: descriptor,
                    session: session,
                    policy: policy,
                    riskOverride: nil,
                    isXcodeNativeServer: isXcodeNative
                )
            }
            // 幂等：先移除同名残留（如连接重试），再注册。
            let manager = toolManager
            for adapter in adapters {
                manager?.remove(id: adapter.name)
            }
            for adapter in adapters {
                manager?.add(adapter, pluginID: pluginID)
            }
            registeredTools[serverID] = adapters
            states[serverID] = .connected
            watchUnexpectedTermination(serverID: serverID, session: session)
        } catch {
            await session.disconnect()
            // 迟到的失败不得覆盖断开后的 Disconnected（#401）。
            guard connectGenerations[serverID] == generation else { return }
            sessions[serverID] = nil
            registeredTools[serverID] = nil
            states[serverID] = .error(Self.describe(error))
        }
    }

    public func disconnect(serverID: String) async {
        // 递增连接代次作废在途连接：禁用开关在 Connecting 状态关闭时，
        // 旧连接与 listTools 的迟到完成不得再注册工具或改写状态（#401）。
        connectGenerations[serverID, default: 0] &+= 1
        terminationWatchers[serverID]?.cancel()
        terminationWatchers[serverID] = nil
        let manager = toolManager
        if let tools = registeredTools[serverID] {
            for tool in tools {
                manager?.remove(id: tool.name)
            }
            registeredTools[serverID] = nil
        }
        if let session = sessions[serverID] {
            await session.disconnect()
        }
        sessions[serverID] = nil
        states[serverID] = .disconnected
    }

    public func toggle(serverID: String) async {
        if sessions[serverID] != nil {
            await disconnect(serverID: serverID)
        } else {
            await connect(serverID: serverID)
        }
    }

    /// 服务器配置变更后刷新连接（保存并连接入口使用）。
    public func reconnectIfActive(serverID: String) async {
        if sessions[serverID] != nil {
            await disconnect(serverID: serverID)
        }
        let config = registry.server(id: serverID)
        if config?.enabled == true {
            await connect(serverID: serverID)
        }
    }

    public func state(for serverID: String) -> MCPServerConnectionState {
        states[serverID] ?? .disconnected
    }

    public func connectedToolCount(serverID: String) -> Int {
        registeredTools[serverID]?.count ?? 0
    }

    // MARK: - Shutdown Helpers

    /// 同步移除全部已注册工具（LLM 立即不可见；`onShutdown` 使用）。
    public func removeAllToolsSynchronously() {
        let manager = toolManager
        for tools in registeredTools.values {
            for tool in tools {
                manager?.remove(id: tool.name)
            }
        }
        registeredTools = [:]
    }

    /// 断开全部会话（`onShutdown` 的异步阶段）。
    public func disconnectAllSessions() async {
        for serverID in sessions.keys {
            await disconnect(serverID: serverID)
        }
    }

    /// 测试钩子：注入可观察会话并建立意外退出监视（#473）。
    /// 生产路径只经 `connect(serverID:)` 建立会话，不会调用此方法。
    func attachSessionForTesting(_ session: any MCPServerServing, serverID: String) async {
        sessions[serverID] = session
        watchUnexpectedTermination(serverID: serverID, session: session)
    }

    // MARK: - Unexpected termination (#473)

    /// 订阅会话意外退出：子进程在未主动断开的情况下退出时，立即撤回工具
    /// 并把状态置为 error，不再维持过期的 Running 与失效工具注册（#473）。
    private func watchUnexpectedTermination(serverID: String, session: any MCPServerServing) {
        guard terminationWatchers[serverID] == nil else { return }
        terminationWatchers[serverID] = Task { @MainActor [weak self] in
            guard let stream = await session.unexpectedTerminationEvents() else { return }
            for await exitCode in stream {
                await self?.handleUnexpectedTermination(serverID: serverID, exitCode: exitCode)
                return
            }
        }
    }

    private func handleUnexpectedTermination(serverID: String, exitCode: Int32) async {
        terminationWatchers[serverID] = nil
        // 与显式 disconnect 竞态时后到者生效：会话已被移除就不再重复清理。
        guard sessions[serverID] != nil else { return }

        let manager = toolManager
        if let tools = registeredTools[serverID] {
            for tool in tools {
                manager?.remove(id: tool.name)
            }
            registeredTools[serverID] = nil
        }
        if let session = sessions[serverID] {
            await session.disconnect()
        }
        sessions[serverID] = nil
        states[serverID] = .error(Self.describe(MCPClientError.serverTerminated(exitCode)))
    }

    // MARK: - Errors

    private static func describe(_ error: Error) -> String {
        if let mcpError = error as? MCPClientError {
            switch mcpError {
            case .invalidConfiguration(let message):
                return "配置无效：\(message)"
            case .notConnected:
                return "服务器未连接"
            case .processSpawnFailed(let message):
                return "进程启动失败：\(message)"
            case .serverTerminated(let code):
                return "服务器进程已退出（码 \(code)）"
            case .transport(let message):
                return "传输错误：\(message)"
            }
        }
        return error.localizedDescription
    }
}
