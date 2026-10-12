import Foundation
import KitMail

/// 账户 → 会话池（actor）。
///
/// 职责：
/// - 按账户懒连接（首次使用才建会话，凭据从 `MailAccountStore` Keychain 取）；
/// - 断线重连：`session(for:)` 对已断开/失败的会话重试创建；
/// - `onShutdown` 全断（插件卸载/退出时释放连接）。
public actor MailSessionManager {
    private let factory: any MailSessionFactory
    private var sessions: [UUID: any MailSessionServing] = [:]

    public init(factory: any MailSessionFactory = MailCoreAdapterFactory()) {
        self.factory = factory
    }

    /// 返回已连接会话；不存在或已断开则创建并连接。
    /// 认证失败抛 `.authFailed`（UI 层提示用户检查凭据）。
    public func session(for account: MailAccountConfig) async throws -> any MailSessionServing {
        if let existing = sessions[account.id] {
            return existing
        }
        guard let password = MailAccountStore.password(for: account.id) else {
            throw MailError.authFailed
        }
        let session = try await factory.makeSession(account: account, password: password)
        try await session.connect()
        sessions[account.id] = session
        return session
    }

    /// 连接测试（表单「连接测试」按钮）：临时建会话 → 连接 → 立即断开，不缓存。
    /// 认证失败抛 `.authFailed`，网络不可达抛 `.network`。
    public func testConnection(account: MailAccountConfig, password: String) async throws {
        let session = try await factory.makeSession(account: account, password: password)
        try await session.connect()
        await session.disconnect()
    }

    /// 显式断开单个账户（删除账户 / 切换凭据时调用）。
    public func disconnect(accountID: UUID) async {
        guard let session = sessions.removeValue(forKey: accountID) else { return }
        await session.disconnect()
    }

    /// 断开全部会话（插件 onShutdown）。
    public func disconnectAll() async {
        let all = sessions.values
        sessions.removeAll()
        for session in all {
            await session.disconnect()
        }
    }

    /// 已建立会话的账户数（供 UI 展示 / 测试断言）。
    public var activeCount: Int {
        sessions.count
    }
}
