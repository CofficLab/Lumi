import Foundation
import KitKeychain
import KitMail

/// 邮件账户配置的持久化存储。
///
/// 存储策略（与 `DatabaseConnectionStore` 一致）：
/// - 配置本体（**不含密码**）以 JSON 存入 `UserDefaults`；
/// - 密码按账户 ID 单独存入系统 Keychain（KitKeychain），避免明文落盘；
/// - 任何序列化/日志路径都不得携带密码（保存前脱敏）。
public enum MailAccountStore {
    private static let accountsKey = "MailPlugin.savedAccounts"
    private static let keychain = KeychainStore(
        service: keychainService
    )
    /// 保持 release/debug 的既有 Keychain 命名空间，避免迁移后丢失保存的密码。
    private static var keychainService: String {
        guard let suffix = Bundle.main.object(forInfoDictionaryKey: "LumiKeychainServiceSuffix") as? String,
              !suffix.isEmpty,
              !suffix.contains("$(") else {
            return "com.coffic.lumi.mail"
        }
        return "com.coffic.lumi.mail" + suffix
    }

    // MARK: - 账户配置

    /// 读取已保存的账户配置（不含密码，密码需用 `password(for:)` 单独取）。
    public static func loadAccounts() -> [MailAccountConfig] {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let decoded = try? JSONDecoder().decode([MailAccountConfig].self, from: data) else {
            return []
        }
        return decoded
    }

    /// 保存账户配置。`config` 中的 password 字段本就不该存在
    /// （`MailAccountConfig` 无密码属性）；密码写入 Keychain 由
    /// `setPassword(_:for:)` 单独完成。
    public static func saveAccounts(_ accounts: [MailAccountConfig]) {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }

    /// 追加或更新单个账户（按 id 匹配），返回更新后的全量列表。
    @discardableResult
    public static func upsertAccount(_ account: MailAccountConfig) -> [MailAccountConfig] {
        var accounts = loadAccounts()
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        saveAccounts(accounts)
        return accounts
    }

    /// 删除账户及其 Keychain 密码。
    public static func deleteAccount(id: UUID) {
        deletePassword(for: id)
        saveAccounts(loadAccounts().filter { $0.id != id })
    }

    // MARK: - 密码（Keychain）

    public static func password(for accountID: UUID) -> String? {
        keychain.string(forKey: passwordKey(for: accountID))
    }

    public static func setPassword(_ password: String?, for accountID: UUID) {
        guard let password, !password.isEmpty else {
            deletePassword(for: accountID)
            return
        }
        keychain.set(password, forKey: passwordKey(for: accountID))
    }

    public static func deletePassword(for accountID: UUID) {
        keychain.remove(forKey: passwordKey(for: accountID))
    }

    // MARK: - 测试隔离

    /// 清空已保存的账户与 Keychain 密码（仅供测试隔离使用）。
    public static func reset() {
        for account in loadAccounts() {
            deletePassword(for: account.id)
        }
        UserDefaults.standard.removeObject(forKey: accountsKey)
    }

    // MARK: - Helpers

    private static func passwordKey(for accountID: UUID) -> String {
        "account.\(accountID.uuidString)"
    }
}
