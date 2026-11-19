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
    private let accountStore: MailAccountStore
    private var sessions: [UUID: any MailSessionServing] = [:]

    /// 账户配置代次（#400）：每次 `disconnect`（编辑凭据 / 删除账户）与
    /// `disconnectAll` 递增。建立中的连接完成后必须代次未变才能入池——
    /// 否则迟到的旧凭据会话会被写回缓存，之后的新配置请求一直复用它。
    private var generations: [UUID: Int] = [:]

    public init(
        factory: any MailSessionFactory = MailCoreAdapterFactory(),
        accountStore: MailAccountStore
    ) {        self.factory = factory
        self.accountStore = accountStore
    }

    /// 返回已连接会话；不存在或已断开则创建并连接。
    /// 认证失败抛 `.authFailed`（UI 层提示用户检查凭据）。
    public func session(for account: MailAccountConfig) async throws -> any MailSessionServing {
        if let existing = sessions[account.id] {
            return existing
        }
        // 调用方持有的配置快照可能已过期：设置页保存编辑后不会通知工作区
        // 重载 accounts，首次冷连接若用快照里的旧 host/用户名建连，会一直
        // 连到旧服务器（#400）。缓存按 id 键控，这里一律以存储中的当前
        // 配置建连；账户已删除则报 notFound。
        guard let current = accountStore.loadAccounts().first(where: { $0.id == account.id }) else {
            throw MailError.notFound
        }
        guard let password = accountStore.password(for: current.id) else {
            throw MailError.authFailed
        }
        let generation = generations[current.id, default: 0]
        let session = try await factory.makeSession(account: current, password: password)
        try await session.connect()
        guard generations[current.id, default: 0] == generation else {
            // 等待期间账户被编辑/删除（#400）：迟到的旧凭据连接既不入池也
            // 不交给调用方，关闭后作废；下一次调用会用新配置重新建连。
            await session.disconnect()
            throw MailError.connectionInvalidated
        }
        sessions[current.id] = session
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
    /// 递增配置代次，使还在建立中的旧凭据连接完成后被作废（#400）。
    public func disconnect(accountID: UUID) async {
        generations[accountID, default: 0] += 1
        guard let session = sessions.removeValue(forKey: accountID) else { return }
        await session.disconnect()
    }

    /// 断开全部会话（插件 onShutdown）。
    public func disconnectAll() async {
        let all = sessions.values
        sessions.removeAll()
        // 同样作废在途连接：账户不在缓存里时 disconnect 路径摸不到它（#400）。
        for account in accountStore.loadAccounts() {
            generations[account.id, default: 0] += 1
        }
        for session in all {
            await session.disconnect()
        }
    }

    /// 已建立会话的账户数（供 UI 展示 / 测试断言）。
    public var activeCount: Int {
        sessions.count
    }
}
