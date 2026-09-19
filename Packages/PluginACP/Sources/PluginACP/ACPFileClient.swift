import Foundation
import ProviderACP

/// Client 文件系统桥的错误。
public enum ACPFileClientError: Error, LocalizedError, Equatable {
    /// Client 未声明对应 fs 能力（ACP 要求此时 MUST NOT 调用）。
    case capabilityUnavailable(method: String)
    /// 路径不是绝对路径（ACP 强制要求）。
    case pathNotAbsolute(String)
    /// 路径越出会话工作目录（防越权读写）。
    case pathOutsideWorkspace(path: String, root: String)
    /// Client 响应无法解析。
    case invalidResponse
    /// 未知会话。
    case unknownSession(ACPSessionId)

    public var errorDescription: String? {
        switch self {
        case .capabilityUnavailable(let method):
            return "Client does not support \(method)"
        case .pathNotAbsolute(let path):
            return "Path must be absolute: \(path)"
        case .pathOutsideWorkspace(let path, let root):
            return "Path is outside the session workspace (\(root)): \(path)"
        case .invalidResponse:
            return "Client returned an invalid response"
        case .unknownSession(let id):
            return "Unknown session: \(id.rawValue)"
        }
    }
}

/// 编辑器文件系统桥（ACP Client 能力）。
///
/// 当 Client 在 `initialize` 中声明 `fs.readTextFile` / `fs.writeTextFile` 时，
/// 文件读写可改走编辑器环境，从而获得：
/// - 未保存缓冲区语义（读到编辑器内的最新内容）；
/// - 编辑器原生 diff 视图（写入后用户可见变更）。
///
/// 约束（与 ACP 规范一致）：
/// - 只使用**绝对路径**；
/// - 未声明能力时 **MUST NOT** 发起对应调用；
/// - 路径必须位于会话工作目录内（`session/new` 的 `cwd`），防止越权读写。
@MainActor
public final class ACPFileClient {
    private let requester: ACPClientRequester
    private let capabilities: ACPClientCapabilitiesStore
    private let sessions: ACPSessionManager

    public init(
        requester: ACPClientRequester,
        capabilities: ACPClientCapabilitiesStore,
        sessions: ACPSessionManager
    ) {
        self.requester = requester
        self.capabilities = capabilities
        self.sessions = sessions
    }

    /// 该会话是否可用编辑器读能力。
    public func canRead(sessionID: ACPSessionId) -> Bool {
        capabilities.readTextFile && sessions.record(for: sessionID) != nil
    }

    /// 该会话是否可用编辑器写能力。
    public func canWrite(sessionID: ACPSessionId) -> Bool {
        capabilities.writeTextFile && sessions.record(for: sessionID) != nil
    }

    // MARK: - 读

    /// 经编辑器读取文本文件。
    ///
    /// - Parameters:
    ///   - path: 绝对路径。
    ///   - line: 起始行（1-based，可选）。
    ///   - limit: 最多读取行数（可选）。
    /// - Returns: 文件文本内容。
    public func readTextFile(
        sessionID: ACPSessionId,
        path: String,
        line: Int? = nil,
        limit: Int? = nil
    ) async throws -> String {
        guard capabilities.readTextFile else {
            throw ACPFileClientError.capabilityUnavailable(method: ACPMethod.fsReadTextFile)
        }
        let resolved = try resolvedPath(path, sessionID: sessionID)
        let params = ACPReadTextFileParams(sessionId: sessionID, path: resolved, line: line, limit: limit)
        let result = try await requester.request(
            method: ACPMethod.fsReadTextFile,
            params: try JSONValue.stringify(params),
            sessionID: sessionID
        )
        guard let result,
              let decoded = try? result.decoded(as: ACPReadTextFileResult.self) else {
            throw ACPFileClientError.invalidResponse
        }
        return decoded.content
    }

    // MARK: - 写

    /// 经编辑器写入文本文件（Client 负责在文件不存在时创建）。
    public func writeTextFile(
        sessionID: ACPSessionId,
        path: String,
        content: String
    ) async throws {
        guard capabilities.writeTextFile else {
            throw ACPFileClientError.capabilityUnavailable(method: ACPMethod.fsWriteTextFile)
        }
        let resolved = try resolvedPath(path, sessionID: sessionID)
        let params = ACPWriteTextFileParams(sessionId: sessionID, path: resolved, content: content)
        _ = try await requester.request(
            method: ACPMethod.fsWriteTextFile,
            params: try JSONValue.stringify(params),
            sessionID: sessionID
        )
    }

    // MARK: - 路径校验

    /// 校验并归一化路径：必须是绝对路径且位于会话工作目录内。
    private func resolvedPath(_ path: String, sessionID: ACPSessionId) throws -> String {
        guard let record = sessions.record(for: sessionID) else {
            throw ACPFileClientError.unknownSession(sessionID)
        }
        let expanded = (path as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else {
            throw ACPFileClientError.pathNotAbsolute(path)
        }
        let candidate = URL(fileURLWithPath: expanded).standardizedFileURL
        let root = URL(fileURLWithPath: record.cwd).standardizedFileURL
        guard Self.isContained(candidate, in: root) else {
            throw ACPFileClientError.pathOutsideWorkspace(path: candidate.path, root: root.path)
        }
        return candidate.path
    }

    /// `url` 是否位于 `root` 之内（或等于 root）。
    ///
    /// 使用 `standardizedFileURL` 消解 `..` 与符号链接无关的路径成分，
    /// 并按路径**组件**比较，避免 `/a/bc` 被误判为 `/a/b` 的子路径。
    static func isContained(_ url: URL, in root: URL) -> Bool {
        let rootComponents = root.pathComponents
        let targetComponents = url.pathComponents
        guard targetComponents.count >= rootComponents.count else { return false }
        return Array(targetComponents.prefix(rootComponents.count)) == rootComponents
    }
}
