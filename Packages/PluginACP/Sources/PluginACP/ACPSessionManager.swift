import Foundation
import ProviderACP

/// 会话创建窄协议。
///
/// 生产环境由 `ConversationManaging`（PluginConversationManager）满足；
/// 测试注入轻量 mock，避免实现整个协议。
@MainActor
public protocol ACPSessionCreating: AnyObject {
    /// 创建一条 Lumi 对话，返回对话 ID。
    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?
    ) throws -> UUID
}

/// ACP 会话 ↔ Lumi 对话 的映射管理器。
///
/// 每个 ACP `sessionId`（形如 `sess_<hex>`）对应一条 Lumi `conversationID`（UUID）。
/// 会话记录同时保存 `cwd`（ACP 文件系统操作边界，M4 使用）。
@MainActor
public final class ACPSessionManager {
    /// 单个 ACP 会话的运行时记录。
    public struct SessionRecord: Sendable {
        public let conversationID: UUID
        public let cwd: String
        public let createdAt: Date

        public init(conversationID: UUID, cwd: String, createdAt: Date = Date()) {
            self.conversationID = conversationID
            self.cwd = cwd
            self.createdAt = createdAt
        }
    }

    private let conversationFactory: any ACPSessionCreating
    private var bySession: [ACPSessionId: SessionRecord] = [:]
    private var byConversation: [UUID: ACPSessionId] = [:]

    public init(conversationFactory: any ACPSessionCreating) {
        self.conversationFactory = conversationFactory
    }

    /// 创建新 ACP 会话：先建 Lumi 对话，再映射会话 ID。
    ///
    /// - Parameters:
    ///   - cwd: 会话工作目录（ACP 要求绝对路径；作为 projectPath 传入 Lumi）。
    ///   - title: 可选对话标题（headless 默认 nil，沿用 Lumi 自动命名）。
    /// - Returns: 新会话 ID。
    public func createSession(cwd: String, title: String? = nil) throws -> ACPSessionId {
        let conversationID = try conversationFactory.createConversation(
            title: title,
            projectPath: cwd,
            providerID: nil,
            modelName: nil
        )
        let sessionID = ACPSessionId(rawValue: Self.newSessionID())
        bySession[sessionID] = SessionRecord(conversationID: conversationID, cwd: cwd)
        byConversation[conversationID] = sessionID
        return sessionID
    }

    /// 会话记录（含 conversationID 与 cwd）。
    public func record(for sessionID: ACPSessionId) -> SessionRecord? {
        bySession[sessionID]
    }

    /// 反向：Lumi 对话 ID → ACP 会话 ID。
    public func sessionID(for conversationID: UUID) -> ACPSessionId? {
        byConversation[conversationID]
    }

    /// 正向：ACP 会话 ID → Lumi 对话 ID。
    public func conversationID(for sessionID: ACPSessionId) -> UUID? {
        bySession[sessionID]?.conversationID
    }

    /// 当前会话数量。
    public var sessionCount: Int { bySession.count }

    /// 移除会话（M2 暂由 `session/close` 预留；当前由调用方决定时机）。
    public func removeSession(_ sessionID: ACPSessionId) {
        guard let record = bySession.removeValue(forKey: sessionID) else { return }
        byConversation.removeValue(forKey: record.conversationID)
    }

    /// 生成 ACP 规范风格的会话 ID：`sess_` + 32 位小写十六进制。
    static func newSessionID() -> String {
        "sess_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
}
