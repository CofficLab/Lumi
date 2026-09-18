import Foundation

// MARK: - fs/read_text_file

/// `fs/read_text_file` 请求参数（Agent → Client）。
/// 参考：https://agentclientprotocol.com/protocol/file-system
public struct ACPReadTextFileParams: Sendable, Equatable, Codable {
    /// 会话 ID。
    public var sessionId: ACPSessionId
    /// 要读取文件的绝对路径。
    public var path: String
    /// 起始行号（1-based，可选）。
    public var line: Int?
    /// 最多读取行数（可选）。
    public var limit: Int?

    public init(sessionId: ACPSessionId, path: String, line: Int? = nil, limit: Int? = nil) {
        self.sessionId = sessionId
        self.path = path
        self.line = line
        self.limit = limit
    }
}

/// `fs/read_text_file` 响应结果。
public struct ACPReadTextFileResult: Sendable, Equatable, Codable {
    /// 文件文本内容。
    public var content: String

    public init(content: String) {
        self.content = content
    }
}

// MARK: - fs/write_text_file

/// `fs/write_text_file` 请求参数（Agent → Client）。
public struct ACPWriteTextFileParams: Sendable, Equatable, Codable {
    /// 会话 ID。
    public var sessionId: ACPSessionId
    /// 要写入文件的绝对路径（不存在则创建）。
    public var path: String
    /// 写入的文本内容。
    public var content: String

    public init(sessionId: ACPSessionId, path: String, content: String) {
        self.sessionId = sessionId
        self.path = path
        self.content = content
    }
}
