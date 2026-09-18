import Foundation
import KitAgentTool
import ProviderACP

/// 编辑器文件系统桥的运行时句柄。
///
/// 工具执行不在 MainActor 上，而 `ACPFileClient` / `ACPSessionManager` 都是
/// `@MainActor`，因此这里用 `@unchecked Sendable` 的轻量包装把「会话解析 +
/// 文件读写」收敛为几个 MainActor 方法，工具只在其中转调。
public final class ACPFileBridge: @unchecked Sendable {
    private let client: ACPFileClient
    private let sessions: ACPSessionManager
    private let capabilities: ACPClientCapabilitiesStore

    public init(
        client: ACPFileClient,
        sessions: ACPSessionManager,
        capabilities: ACPClientCapabilitiesStore
    ) {
        self.client = client
        self.sessions = sessions
        self.capabilities = capabilities
    }

    /// Client 是否已声明完整 fs 能力。
    @MainActor
    public var isFileSystemAvailable: Bool {
        capabilities.hasFileSystemBridge
    }

    /// 经编辑器读取文本。
    @MainActor
    public func read(
        conversationID: UUID,
        path: String,
        line: Int?,
        limit: Int?
    ) async throws -> String {
        guard let sessionID = sessions.sessionID(for: conversationID) else {
            throw ACPFileClientError.unknownSession(ACPSessionId(rawValue: "<no session for conversation>"))
        }
        return try await client.readTextFile(sessionID: sessionID, path: path, line: line, limit: limit)
    }

    /// 经编辑器写入文本。
    @MainActor
    public func write(conversationID: UUID, path: String, content: String) async throws {
        guard let sessionID = sessions.sessionID(for: conversationID) else {
            throw ACPFileClientError.unknownSession(ACPSessionId(rawValue: "<no session for conversation>"))
        }
        try await client.writeTextFile(sessionID: sessionID, path: path, content: content)
    }
}

/// 经编辑器读取文件的桥接工具（覆盖内置 `read_file`）。
///
/// 仅在 Client 声明 `fs.readTextFile` 时注册；未声明时内置 `read_file` 保持不变。
public struct ACPReadFileTool: SuperAgentTool, @unchecked Sendable {
    public let name = "read_file"
    public let executionCapability: ToolExecutionCapability = .parallelReadOnly

    private let bridge: ACPFileBridge

    public init(bridge: ACPFileBridge) {
        self.bridge = bridge
    }

    public func description(for language: LanguagePreference) -> String {
        "Read UTF-8 text from a file through the editor. Returns the editor's current content, including unsaved changes."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute path to the file to read"],
                "line": ["type": "integer", "description": "1-based line number to start reading from"],
                "limit": ["type": "integer", "description": "Maximum number of lines to read"],
            ],
            "required": ["path"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let path = arguments.stringValue("path") else { return "读取文件" }
        return "读取 \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        guard let path = arguments.stringValue("path") else {
            throw ACPToolError.missingArgument("path")
        }
        let content = try await bridge.read(
            conversationID: context.conversationID,
            path: path,
            line: arguments.intValue("line"),
            limit: arguments.intValue("limit")
        )
        return ToolCallResult(content: content)
    }
}

/// 经编辑器写入文件的桥接工具（覆盖内置 `write_file`）。
///
/// 写入走编辑器后，编辑器侧 diff 视图可直接呈现本次变更。
public struct ACPWriteFileTool: SuperAgentTool, @unchecked Sendable {
    public let name = "write_file"
    public let executionCapability: ToolExecutionCapability = .serialSideEffect

    private let bridge: ACPFileBridge

    public init(bridge: ACPFileBridge) {
        self.bridge = bridge
    }

    public func description(for language: LanguagePreference) -> String {
        "Write UTF-8 text content to a file through the editor."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute path to the file to write"],
                "content": ["type": "string", "description": "UTF-8 text content to write"],
            ],
            "required": ["path", "content"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .medium }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let path = arguments.stringValue("path") else { return "写入文件" }
        return "写入 \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        guard let path = arguments.stringValue("path") else {
            throw ACPToolError.missingArgument("path")
        }
        guard let content = arguments.stringValue("content") else {
            throw ACPToolError.missingArgument("content")
        }
        try await bridge.write(conversationID: context.conversationID, path: path, content: content)
        return ToolCallResult(content: "Wrote \(content.count) characters to \(path)")
    }
}

/// fs 桥接工具的参数错误。
public enum ACPToolError: Error, LocalizedError, Equatable {
    case missingArgument(String)

    public var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            return "Missing required argument: \(name)"
        }
    }
}

// MARK: - 参数访问

/// 桥接工具的参数读取辅助（与内置文件工具的参数命名保持一致）。
private extension [String: ToolArgument] {
    func stringValue(_ key: String) -> String? {
        self[key]?.value as? String
    }

    func intValue(_ key: String) -> Int? {
        guard let value = self[key]?.value else { return nil }
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }
}
