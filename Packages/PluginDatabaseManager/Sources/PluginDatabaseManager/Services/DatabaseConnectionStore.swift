import Foundation
import KitKeychain

/// 数据库连接配置的持久化存储。
///
/// 存储策略（与同类数据库管理工具一致）：
/// - 配置本体（**不含密码**）以 JSON 存入 `UserDefaults`；
/// - 密码按连接 ID 单独存入系统 Keychain（KitKeychain），避免明文落盘；
/// - 上次成功连接的配置 ID 存入 `UserDefaults`，下次打开时自动重连。
enum DatabaseConnectionStore {
    private static let configsKey = "DatabaseManager.savedConfigs"
    private static let lastSelectedKey = "DatabaseManager.lastSelectedConfigID"
    /// 默认 Keychain 存储；内部暴露以便视图模型注入与测试替换后端。
    static let keychain = KeychainStore(
        service: keychainService
    )
    /// 保持 release/debug 的既有 Keychain 命名空间，避免迁移后丢失保存的密码。
    private static var keychainService: String {
        guard let suffix = Bundle.main.object(forInfoDictionaryKey: "LumiKeychainServiceSuffix") as? String,
              !suffix.isEmpty,
              !suffix.contains("$(") else {
            return "com.coffic.lumi.database-manager"
        }
        return "com.coffic.lumi.database-manager" + suffix
    }

    // MARK: - Configs

    /// 读取已保存的配置，并从 Keychain 回填密码。
    static func loadConfigs(keychain: KeychainStore = keychain) -> [DatabaseConfig] {
        guard let data = UserDefaults.standard.data(forKey: configsKey),
              var decoded = try? JSONDecoder().decode([DatabaseConfig].self, from: data) else {
            return []
        }
        for index in decoded.indices {
            decoded[index].password = password(for: decoded[index].id, keychain: keychain)
        }
        return decoded
    }

    /// 保存配置：密码写入 Keychain，UserDefaults 中只存脱敏后的副本。
    ///
    /// 密码写入失败必须向上抛出，且**不得**把脱敏配置落盘——否则界面会把
    /// 「密码已丢失」的配置呈现为保存成功，重启后凭据无法恢复（#569）。
    /// 因此先完成全部 Keychain 写入，最后才写 UserDefaults。
    static func saveConfigs(_ configs: [DatabaseConfig], keychain: KeychainStore = keychain) throws {
        var sanitized = configs
        for index in sanitized.indices {
            if let password = configs[index].password, !password.isEmpty {
                try keychain.setReportingErrors(password, forKey: passwordKey(for: configs[index].id))
            }
            sanitized[index].password = nil
        }
        let data = try JSONEncoder().encode(sanitized)
        UserDefaults.standard.set(data, forKey: configsKey)
    }

    /// 删除配置对应的 Keychain 密码。
    static func deletePassword(for configID: UUID, keychain: KeychainStore = keychain) {
        keychain.remove(forKey: passwordKey(for: configID))
    }

    /// 清空已保存的配置与「上次选中」记录（仅供测试隔离使用）。
    static func resetSavedConfigs() {
        UserDefaults.standard.removeObject(forKey: configsKey)
        UserDefaults.standard.removeObject(forKey: lastSelectedKey)
    }

    // MARK: - Last Selected

    /// 上次成功连接的配置 ID；显式断开后应置 nil（不再自动重连）。
    static var lastSelectedConfigID: UUID? {
        get {
            UserDefaults.standard.string(forKey: lastSelectedKey).flatMap(UUID.init(uuidString:))
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: lastSelectedKey)
            } else {
                UserDefaults.standard.removeObject(forKey: lastSelectedKey)
            }
        }
    }

    // MARK: - Helpers

    private static func password(for configID: UUID, keychain: KeychainStore = keychain) -> String? {
        keychain.string(forKey: passwordKey(for: configID))
    }

    private static func passwordKey(for configID: UUID) -> String {
        "connection.\(configID.uuidString)"
    }
}
