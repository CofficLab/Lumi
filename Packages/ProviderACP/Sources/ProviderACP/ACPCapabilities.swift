import Foundation

// MARK: - 实现信息

/// Client / Agent 实现信息（`clientInfo` / `agentInfo`）。
/// 参考：https://agentclientprotocol.com/protocol/initialization
public struct ACPImplementationInfo: Sendable, Equatable, Codable {
    /// 程序化/逻辑用途的名称。
    public var name: String
    /// 面向 UI 展示的名称（缺省时用 name）。
    public var title: String?
    /// 实现版本。
    public var version: String?

    public init(name: String, title: String? = nil, version: String? = nil) {
        self.name = name
        self.title = title
        self.version = version
    }
}

// MARK: - Client 能力

/// Client 能力（`initialize` 请求中声明；未声明一律视为不支持）。
public struct ACPClientCapabilities: Sendable, Equatable, Codable {
    /// 文件系统能力。
    public var fs: ACPFSClientCapabilities?
    /// 终端能力（`terminal/*` 方法可用）。
    public var terminal: Bool?

    public init(fs: ACPFSClientCapabilities? = nil, terminal: Bool? = nil) {
        self.fs = fs
        self.terminal = terminal
    }
}

/// Client 文件系统能力。
public struct ACPFSClientCapabilities: Sendable, Equatable, Codable {
    /// `fs/read_text_file` 可用。
    public var readTextFile: Bool?
    /// `fs/write_text_file` 可用。
    public var writeTextFile: Bool?

    public init(readTextFile: Bool? = nil, writeTextFile: Bool? = nil) {
        self.readTextFile = readTextFile
        self.writeTextFile = writeTextFile
    }
}

// MARK: - Agent 能力

/// Agent 能力（`initialize` 响应中声明；未声明一律视为不支持）。
public struct ACPAgentCapabilities: Sendable, Equatable, Codable {
    /// `session/load` 可用（默认 false）。
    public var loadSession: Bool?
    /// 提示内容能力（text / resource_link 为基线，无需声明）。
    public var promptCapabilities: ACPPromptCapabilities?
    /// MCP 传输能力。
    public var mcpCapabilities: ACPMCPCapabilities?
    /// 认证相关能力。
    public var auth: ACPAuthCapabilities?
    /// 会话能力（resume / close）。
    public var sessionCapabilities: ACPSessionCapabilities?

    public init(
        loadSession: Bool? = nil,
        promptCapabilities: ACPPromptCapabilities? = nil,
        mcpCapabilities: ACPMCPCapabilities? = nil,
        auth: ACPAuthCapabilities? = nil,
        sessionCapabilities: ACPSessionCapabilities? = nil
    ) {
        self.loadSession = loadSession
        self.promptCapabilities = promptCapabilities
        self.mcpCapabilities = mcpCapabilities
        self.auth = auth
        self.sessionCapabilities = sessionCapabilities
    }
}

/// 提示内容能力（image / audio / embeddedContext 均为默认 false）。
public struct ACPPromptCapabilities: Sendable, Equatable, Codable {
    public var image: Bool?
    public var audio: Bool?
    public var embeddedContext: Bool?

    public init(image: Bool? = nil, audio: Bool? = nil, embeddedContext: Bool? = nil) {
        self.image = image
        self.audio = audio
        self.embeddedContext = embeddedContext
    }
}

/// MCP 传输能力。
public struct ACPMCPCapabilities: Sendable, Equatable, Codable {
    /// 支持 HTTP 传输（默认 false）。
    public var http: Bool?
    /// 支持 SSE 传输（默认 false；已被 MCP 规范废弃）。
    public var sse: Bool?

    public init(http: Bool? = nil, sse: Bool? = nil) {
        self.http = http
        self.sse = sse
    }
}

/// 认证能力。
public struct ACPAuthCapabilities: Sendable, Equatable, Codable {
    /// `logout` 方法可用。
    public var logout: ACPLogoutCapabilities?

    public init(logout: ACPLogoutCapabilities? = nil) {
        self.logout = logout
    }
}

public struct ACPLogoutCapabilities: Sendable, Equatable, Codable {
    public init() {}
}

/// 会话能力（resume / close）。
public struct ACPSessionCapabilities: Sendable, Equatable, Codable {
    /// `session/resume` 可用（空对象表示支持）。
    public var resume: ACPEmptyCapability?
    /// `session/close` 可用（空对象表示支持）。
    public var close: ACPEmptyCapability?

    public init(resume: ACPEmptyCapability? = nil, close: ACPEmptyCapability? = nil) {
        self.resume = resume
        self.close = close
    }
}

/// 空能力对象（`{}`）。
public struct ACPEmptyCapability: Sendable, Equatable, Codable {
    public init() {}
}

// MARK: - initialize

/// `initialize` 请求参数。
public struct ACPInitializeParams: Sendable, Equatable, Codable {
    /// Client 支持的最新协议主版本。
    public var protocolVersion: Int
    /// Client 能力。
    public var clientCapabilities: ACPClientCapabilities
    /// Client 实现信息。
    public var clientInfo: ACPImplementationInfo?

    public init(
        protocolVersion: Int,
        clientCapabilities: ACPClientCapabilities,
        clientInfo: ACPImplementationInfo? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.clientCapabilities = clientCapabilities
        self.clientInfo = clientInfo
    }
}

/// `initialize` 响应结果。
public struct ACPInitializeResult: Sendable, Equatable, Codable {
    /// 双方约定的协议主版本。
    public var protocolVersion: Int
    /// Agent 能力。
    public var agentCapabilities: ACPAgentCapabilities
    /// Agent 实现信息。
    public var agentInfo: ACPImplementationInfo?
    /// 支持的认证方法列表（空表示无需认证）。
    public var authMethods: [String]?

    public init(
        protocolVersion: Int,
        agentCapabilities: ACPAgentCapabilities,
        agentInfo: ACPImplementationInfo? = nil,
        authMethods: [String]? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.agentCapabilities = agentCapabilities
        self.agentInfo = agentInfo
        self.authMethods = authMethods
    }
}
