import Foundation

/// MCP 传输方式。
public enum MCPTransport: String, Codable, Hashable, Sendable {
    /// 本地子进程：客户端 spawn 服务器命令，经 stdin/stdout 交换 newline-delimited JSON-RPC。
    case stdio
    /// 远程端点：Streamable HTTP（含 SSE）。
    case streamableHTTP
}

/// 一个可配置的 MCP 服务器（用户可编辑、可持久化）。
public struct MCPServerConfig: Codable, Hashable, Sendable {
    /// 全局唯一 ID，同时作为工具命名空间前缀（`{id}.{toolName}`）。
    public var id: String
    /// 显示名称。
    public var name: String
    /// 可执行文件路径或命令名（如 `xcrun`、`npx`、`uvx`）。
    public var command: String
    /// 命令参数（如 `["mcpbridge"]`）。
    public var arguments: [String]
    /// 附加环境变量（合并到进程环境之上）。
    public var environment: [String: String]
    /// 传输方式。
    public var transport: MCPTransport
    /// Streamable HTTP 时的端点地址（仅 `transport == .streamableHTTP` 使用）。
    public var url: String?
    /// 是否在需要时自动启动（首次工具调用前）。默认关闭，显式启动。
    public var autoStart: Bool
    /// 是否启用；禁用时不 spawn、不注册工具。
    public var enabled: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        command: String,
        arguments: [String] = [],
        environment: [String: String] = [:],
        transport: MCPTransport = .stdio,
        url: String? = nil,
        autoStart: Bool = false,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.transport = transport
        self.url = url
        self.autoStart = autoStart
        self.enabled = enabled
    }
}

/// 内置服务器预设模板（PluginMCP 首次落库用，用户可改可删）。
public enum MCPServerTemplate {
    /// Apple 官方：Xcode 26.3+ 的 `xcrun mcpbridge`。
    /// 需 Xcode 运行且开启 Intelligence → Model Context Protocol 授权。
    public static let xcodeNative = MCPServerConfig(
        name: "Xcode (native)",
        command: "xcrun",
        arguments: ["mcpbridge"]
    )
}
