import Foundation

// MARK: - SessionId

/// ACP 会话 ID（`sess_...` 风格字符串）。
/// 参考：https://agentclientprotocol.com/protocol/session-setup
public struct ACPSessionId: RawRepresentable, Sendable, Equatable, Hashable, Codable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - MCP Server 配置

/// MCP server 传输配置（stdio / http / sse）。
/// 参考：https://agentclientprotocol.com/protocol/session-setup
public enum ACPMCPServer: Sendable, Equatable {
    /// stdio 传输（所有 Agent 必须支持）。
    case stdio(name: String, command: String, args: [String], env: [ACPMCPEnvVariable])
    /// HTTP 传输（需 `mcpCapabilities.http`）。
    case http(name: String, url: String, headers: [ACPMCPHttpHeader])
    /// SSE 传输（需 `mcpCapabilities.sse`；已被 MCP 规范废弃）。
    case sse(name: String, url: String, headers: [ACPMCPHttpHeader])
}

/// MCP stdio 环境变量。
public struct ACPMCPEnvVariable: Sendable, Equatable, Codable {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

/// MCP HTTP 请求头。
public struct ACPMCPHttpHeader: Sendable, Equatable, Codable {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

extension ACPMCPServer: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, name, command, args, env, url, headers
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decodeIfPresent(String.self, forKey: .type)
        let name = try c.decode(String.self, forKey: .name)
        if type == "http" {
            self = .http(
                name: name,
                url: try c.decode(String.self, forKey: .url),
                headers: try c.decodeIfPresent([ACPMCPHttpHeader].self, forKey: .headers) ?? []
            )
        } else if type == "sse" {
            self = .sse(
                name: name,
                url: try c.decode(String.self, forKey: .url),
                headers: try c.decodeIfPresent([ACPMCPHttpHeader].self, forKey: .headers) ?? []
            )
        } else {
            // stdio（type 缺省即 stdio）
            self = .stdio(
                name: name,
                command: try c.decode(String.self, forKey: .command),
                args: try c.decodeIfPresent([String].self, forKey: .args) ?? [],
                env: try c.decodeIfPresent([ACPMCPEnvVariable].self, forKey: .env) ?? []
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .stdio(let name, let command, let args, let env):
            try c.encode(name, forKey: .name)
            try c.encode(command, forKey: .command)
            try c.encode(args, forKey: .args)
            try c.encode(env, forKey: .env)
        case .http(let name, let url, let headers):
            try c.encode("http", forKey: .type)
            try c.encode(name, forKey: .name)
            try c.encode(url, forKey: .url)
            try c.encode(headers, forKey: .headers)
        case .sse(let name, let url, let headers):
            try c.encode("sse", forKey: .type)
            try c.encode(name, forKey: .name)
            try c.encode(url, forKey: .url)
            try c.encode(headers, forKey: .headers)
        }
    }
}

// MARK: - 会话模式

/// 会话模式状态（`session/new` 响应可选返回）。
/// 参考：https://agentclientprotocol.com/protocol/session-modes
public struct ACPSessionModeState: Sendable, Equatable, Codable {
    /// 当前激活模式 ID。
    public var currentModeId: String
    /// 可用模式列表。
    public var availableModes: [ACPSessionMode]

    public init(currentModeId: String, availableModes: [ACPSessionMode]) {
        self.currentModeId = currentModeId
        self.availableModes = availableModes
    }
}

public struct ACPSessionMode: Sendable, Equatable, Codable {
    /// 模式唯一 ID。
    public var id: String
    /// 展示名称。
    public var name: String
    /// 模式说明（可选）。
    public var description: String?

    public init(id: String, name: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

// MARK: - session/new

/// `session/new` 请求参数。
public struct ACPSessionNewParams: Sendable, Equatable, Codable {
    /// 会话工作目录（绝对路径，文件系统操作边界）。
    public var cwd: String
    /// Agent 应连接的 MCP server 列表（可选）。
    public var mcpServers: [ACPMCPServer]?

    public init(cwd: String, mcpServers: [ACPMCPServer]? = nil) {
        self.cwd = cwd
        self.mcpServers = mcpServers
    }
}

/// `session/new` 响应结果。
public struct ACPSessionNewResult: Sendable, Equatable, Codable {
    /// 新会话 ID。
    public var sessionId: ACPSessionId
    /// 可选：会话模式状态。
    public var modes: ACPSessionModeState?

    public init(sessionId: ACPSessionId, modes: ACPSessionModeState? = nil) {
        self.sessionId = sessionId
        self.modes = modes
    }
}

// MARK: - session/prompt

/// `session/prompt` 请求参数。
/// 参考：https://agentclientprotocol.com/protocol/prompt-turn
public struct ACPPromptParams: Sendable, Equatable, Codable {
    /// 目标会话 ID。
    public var sessionId: ACPSessionId
    /// 用户提示内容块列表。
    public var prompt: [ContentBlock]

    public init(sessionId: ACPSessionId, prompt: [ContentBlock]) {
        self.sessionId = sessionId
        self.prompt = prompt
    }
}

/// `session/prompt` 响应结果。
public struct ACPPromptResult: Sendable, Equatable, Codable {
    /// 回合停止原因。
    public var stopReason: StopReason

    public init(stopReason: StopReason) {
        self.stopReason = stopReason
    }
}

// MARK: - session/cancel（通知）

/// `session/cancel` 通知参数。
public struct ACPCancelParams: Sendable, Equatable, Codable {
    /// 要取消回合的会话 ID。
    public var sessionId: ACPSessionId

    public init(sessionId: ACPSessionId) {
        self.sessionId = sessionId
    }
}

// MARK: - session/load / resume / close

/// `session/load` 与 `session/resume` 共享请求参数。
public struct ACPSessionLoadParams: Sendable, Equatable, Codable {
    /// 要加载/恢复的会话 ID。
    public var sessionId: ACPSessionId
    /// 工作目录。
    public var cwd: String
    /// MCP server 列表（可选）。
    public var mcpServers: [ACPMCPServer]?

    public init(sessionId: ACPSessionId, cwd: String, mcpServers: [ACPMCPServer]? = nil) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.mcpServers = mcpServers
    }
}

/// `session/close` 请求参数。
public struct ACPSessionCloseParams: Sendable, Equatable, Codable {
    /// 要关闭的会话 ID。
    public var sessionId: ACPSessionId

    public init(sessionId: ACPSessionId) {
        self.sessionId = sessionId
    }
}

// MARK: - session/set_mode

/// `session/set_mode` 请求参数。
public struct ACPSetModeParams: Sendable, Equatable, Codable {
    /// 目标会话 ID。
    public var sessionId: ACPSessionId
    /// 要切换的模式 ID（必须属于 `availableModes`）。
    public var modeId: String

    public init(sessionId: ACPSessionId, modeId: String) {
        self.sessionId = sessionId
        self.modeId = modeId
    }
}
