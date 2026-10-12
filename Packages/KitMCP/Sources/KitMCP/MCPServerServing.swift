import Foundation

/// KitMCP 统一错误类型。
public enum MCPClientError: Error, Sendable, Equatable {
    /// 配置不完整（如 HTTP 传输缺少 URL）。
    case invalidConfiguration(String)
    /// 尚未连接就尝试 listTools / callTool。
    case notConnected
    /// 服务器子进程启动失败。
    case processSpawnFailed(String)
    /// 服务器子进程已退出（含退出码）。
    case serverTerminated(Int32)
    /// 底层 SDK / 协议层错误。
    case transport(String)
}

/// MCP 客户端会话薄抽象。
///
/// 上层（PluginMCP）只依赖此协议，不感知底层 SDK 与传输实现；
/// 便于后续替换 `swift-sdk` 或自实现 JSON-RPC 客户端。
public protocol MCPServerServing: Sendable {
    /// 是否已连接。
    var isConnected: Bool { get async }
    /// 服务器配置（只读快照）。
    var config: MCPServerConfig { get }
    /// 建立连接（stdio：spawn 子进程并握手；HTTP：连接端点并握手）。
    func connect() async throws
    /// 断开连接并清理资源（stdio 会终止子进程）。
    func disconnect() async
    /// 列出服务器暴露的全部工具。
    func listTools() async throws -> [MCPToolDescriptor]
    /// 调用一个工具。
    func callTool(name: String, arguments: [String: MCPJSONValue]) async throws -> MCPCallResult
}
