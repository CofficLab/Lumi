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
        switch self {
        case .disconnected: return "已断开"
        case .connecting: return "连接中…"
        case .connected: return "运行中"
        case .error: return "错误"
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

    public init(
        registry: MCPServerRegistry,
        toolManager: (any ToolManagerProviding)?,
        pluginID: String,
        policy: MCPPermissionPolicy = MCPPermissionPolicy()
    ) {
        self.registry = registry
        self.toolManager = toolManager
        self.pluginID = pluginID
        self.policy = policy
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
        let session = MCPServerSession(config: config)
        sessions[serverID] = session
        do {
            try await session.connect()
            let descriptors = try await session.listTools()
            let adapters = descriptors.map { descriptor in
                MCPToolAdapter(
                    serverID: serverID,
                    serverName: config.name,
                    descriptor: descriptor,
                    session: session,
                    policy: policy,
                    riskOverride: registry.riskOverride(serverID: serverID, toolName: descriptor.name)
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
        } catch {
            await session.disconnect()
            sessions[serverID] = nil
            registeredTools[serverID] = nil
            states[serverID] = .error(Self.describe(error))
        }
    }

    public func disconnect(serverID: String) async {
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
