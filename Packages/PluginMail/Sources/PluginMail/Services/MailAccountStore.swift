import Foundation
import KitKeychain
import KitMail
import os
import LumiLoggingKit

/// 邮件账户配置的持久化存储。
///
/// 存储策略（对齐插件标准存储层）：
/// - 配置本体（**不含密码**）落在插件数据目录的 `accounts.plist`，
///   目录由 `StorageProviding.pluginDataDirectory(for:)` 提供；
/// - 密码按账户 ID 单独存入系统 Keychain（KitKeychain），避免明文落盘；
/// - 任何序列化/日志路径都不得携带密码。
///
/// ## 为什么是实例而不是 `enum` + 静态方法
///
/// 早期实现把 `UserDefaults.standard` 与 `KeychainStore(service:)` 硬编码在
/// 静态成员里，导致单元测试只能读写**用户真实数据**：测试既不稳定
/// （`loadAccounts().isEmpty` 取决于本机是否配过邮箱），又会**破坏用户数据**
/// （`reset()` 会删掉真实 Keychain 里的邮箱密码）。
///
/// 现在存储目标与迁移数据源都是构造参数，测试传临时目录 + stub backend
/// 即可完全隔离；生产侧由 `MailPlugin.onBoot` 用 Provider 解析出的
/// 插件数据目录构造。
public final class MailAccountStore: SuperLog, @unchecked Sendable {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.mail",
        category: "mail-account-store"
    )

    /// plist 内的 envelope key，值为 `JSONEncoder` 编码的 `[MailAccountConfig]`。
    private static let accountsKey = "accounts"
    /// 迁移完成标记。写在 plist 内，因此与配置同生共死——删配置即视为
    /// 「重来一次迁移」，不会出现「标记在、数据没了」的错位。
    private static let migrationKey = "migratedFromUserDefaults"
    /// 旧版把账户 JSON 存在 `UserDefaults` 的这个 key 下。
    private static let legacyDefaultsKey = "MailPlugin.savedAccounts"

    private let settingsFileURL: URL
    private let keychain: KeychainStore
    private let fileManager: FileManager
    private let queue: DispatchQueue
    /// 旧配置的读取源。为 `nil` 表示不做迁移。
    private let legacyDefaults: UserDefaults?

    /// 在指定插件数据目录下构造 store。
    ///
    /// - Parameters:
    ///   - directory: 插件数据目录（`<dbRoot>/<pluginID>/`）。
    ///   - keychain: 密码存储；生产传真实 Keychain，测试传 stub backend。
    ///   - legacyDefaults: 旧版 `UserDefaults` 数据源；传 `nil` 跳过迁移。
    public convenience init(
        directory: URL,
        keychain: KeychainStore,
        legacyDefaults: UserDefaults? = nil
    ) {
        self.init(
            directory: directory,
            keychainProvider: { keychain },
            legacyDefaults: legacyDefaults
        )
    }

    /// 生产构造：使用默认 Keychain service（保持 release/debug 的既有命名空间），
    /// 并从 `UserDefaults.standard` 迁移旧账户配置。
    public convenience init(directory: URL) {
        self.init(
            directory: directory,
            keychainProvider: { KeychainStore(service: Self.keychainService) },
            legacyDefaults: .standard
        )
    }

    private init(
        directory: URL,
        keychainProvider: () -> KeychainStore,
        legacyDefaults: UserDefaults?
    ) {
        self.settingsFileURL = directory.appendingPathComponent("accounts.plist", isDirectory: false)
        self.keychain = keychainProvider()
        self.fileManager = .default
        self.queue = DispatchQueue(label: "com.coffic.lumi.plugin.mail.account-store", qos: .userInitiated)
        self.legacyDefaults = legacyDefaults
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        migrateLegacyAccountsIfNeeded()
    }

    /// 保持 release/debug 的既有 Keychain 命名空间。
    ///
    /// - Important: 迁移**依赖**这个 service 不变——旧密码本就存在同名条目下，
    ///   账户 id 也没变，所以新 plist 里的 id 能直接命中旧 Keychain 条目。
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
    public func loadAccounts() -> [MailAccountConfig] {
        queue.sync { decodeAccounts(from: readPlist()) }
    }

    /// 保存账户配置。`config` 中的 password 字段本就不该存在
    /// （`MailAccountConfig` 无密码属性）；密码写入 Keychain 由
    /// `setPassword(_:for:)` 单独完成。
    public func saveAccounts(_ accounts: [MailAccountConfig]) {
        queue.sync {
            guard let data = try? JSONEncoder().encode(accounts) else {
                Self.logger.error("\(Self.t)编码邮件账户配置失败，已放弃写入")
                return
            }
            var plist = readPlist()
            plist[Self.accountsKey] = data
            writePlist(plist)
        }
    }

    /// 追加或更新单个账户（按 id 匹配），返回更新后的全量列表。
    @discardableResult
    public func upsertAccount(_ account: MailAccountConfig) -> [MailAccountConfig] {
        queue.sync {
            var accounts = decodeAccounts(from: readPlist())
            if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                accounts[index] = account
            } else {
                accounts.append(account)
            }
            guard let data = try? JSONEncoder().encode(accounts) else { return accounts }
            var plist = readPlist()
            plist[Self.accountsKey] = data
            writePlist(plist)
            return accounts
        }
    }

    /// 删除账户及其 Keychain 密码。
    public func deleteAccount(id: UUID) {
        deletePassword(for: id)
        saveAccounts(loadAccounts().filter { $0.id != id })
    }

    // MARK: - 密码（Keychain）

    public func password(for accountID: UUID) -> String? {
        keychain.string(forKey: passwordKey(for: accountID))
    }

    public func setPassword(_ password: String?, for accountID: UUID) {
        guard let password, !password.isEmpty else {
            deletePassword(for: accountID)
            return
        }
        keychain.set(password, forKey: passwordKey(for: accountID))
    }

    public func deletePassword(for accountID: UUID) {
        keychain.remove(forKey: passwordKey(for: accountID))
    }

    // MARK: - 旧版迁移

    /// 一次性把 `UserDefaults` 里的旧账户配置搬进 `accounts.plist`。
    ///
    /// ## 为什么不迁移密码
    ///
    /// 旧密码本来就存在系统 Keychain（service 名未变），**不需要搬**。
    /// 账户 id 也没变，所以新 plist 里的 id 能直接命中旧 Keychain 条目。
    ///
    /// ## 安全性
    ///
    /// - **幂等**：plist 内写 `migratedFromUserDefaults` 标记，重复调用直接返回。
    /// - **失败不丢数据**：任何一步失败都**保留**旧 `UserDefaults` 数据，下次启动再试；
    ///   只有确认 plist 写成功后，才清除旧 key。
    /// - **不覆盖**：若 plist 已有账户，说明用户已有新格式数据，直接标记完成并退出。
    private func migrateLegacyAccountsIfNeeded() {
        queue.sync {
            guard let legacyDefaults else { return }

            var plist = readPlist()
            if plist[Self.migrationKey] != nil { return }

            // 已有账户 = 用户已有新格式数据，绝不覆盖。
            if !decodeAccounts(from: plist).isEmpty {
                plist[Self.migrationKey] = true
                writePlist(plist)
                return
            }

            guard let data = legacyDefaults.data(forKey: Self.legacyDefaultsKey) else {
                // 从未配过邮箱：标记完成，避免每次启动都探测。
                plist[Self.migrationKey] = true
                writePlist(plist)
                return
            }

            let accounts: [MailAccountConfig]
            do {
                accounts = try JSONDecoder().decode([MailAccountConfig].self, from: data)
            } catch {
                Self.logger.error(
                    "\(Self.t)旧版邮件账户配置解码失败，保留 UserDefaults 数据以便重试: \(error.localizedDescription)"
                )
                return
            }

            guard let encoded = try? JSONEncoder().encode(accounts) else {
                Self.logger.error("\(Self.t)旧版邮件账户配置重新编码失败，保留 UserDefaults 数据以便重试")
                return
            }

            plist[Self.accountsKey] = encoded
            plist[Self.migrationKey] = true
            writePlist(plist)

            guard readPlist()[Self.accountsKey] != nil else {
                // 写盘没成功，别删旧数据。
                Self.logger.error("\(Self.t)邮件账户配置写入失败，保留 UserDefaults 数据以便重试")
                return
            }

            legacyDefaults.removeObject(forKey: Self.legacyDefaultsKey)
            Self.logger.info("\(Self.t)已迁移 \(accounts.count) 个旧版邮件账户到 accounts.plist")
        }
    }

    // MARK: - 私有辅助

    private func decodeAccounts(from plist: [String: Any]) -> [MailAccountConfig] {
        guard let data = plist[Self.accountsKey] as? Data else { return [] }
        do {
            return try JSONDecoder().decode([MailAccountConfig].self, from: data)
        } catch {
            Self.logger.error("\(Self.t)解码邮件账户配置失败: \(error.localizedDescription)")
            quarantineCorruptSettings()
            return []
        }
    }

    private func readPlist() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return [:] }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(Self.t)accounts.plist 根节点不是字典")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(Self.t)读取 accounts.plist 失败: \(error.localizedDescription)")
            quarantineCorruptSettings()
            return [:]
        }
    }

    private func writePlist(_ plist: [String: Any]) {
        let plistData: Data
        do {
            plistData = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .binary,
                options: 0
            )
        } catch {
            Self.logger.error("\(Self.t)编码 accounts.plist 失败: \(error.localizedDescription)")
            return
        }

        let parent = settingsFileURL.deletingLastPathComponent()
        let tmp = parent.appendingPathComponent("accounts.tmp", isDirectory: false)
        do {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            try plistData.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try fileManager.replaceItemAt(settingsFileURL, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: settingsFileURL)
            }
        } catch {
            Self.logger.error("\(Self.t)持久化 accounts.plist 失败: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmp)
        }
    }

    /// 把损坏的配置挪到 `.corrupt` 后重置为干净状态，避免每次启动都读到坏数据。
    private func quarantineCorruptSettings() {
        let corrupt = settingsFileURL.deletingLastPathComponent()
            .appendingPathComponent("accounts.corrupt.plist", isDirectory: false)
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return }
        try? fileManager.removeItem(at: corrupt)
        try? fileManager.moveItem(at: settingsFileURL, to: corrupt)
    }

    private func passwordKey(for accountID: UUID) -> String {
        "account.\(accountID.uuidString)"
    }
}
