import Foundation
import KernelLumi
import KeychainKit

/// 数据库连接配置的持久化存储。
///
/// 存储策略（与同类数据库管理工具一致）：
/// - 配置本体（**不含密码**）以 JSON 存入 `UserDefaults`；
/// - 密码按连接 ID 单独存入系统 Keychain（KeychainKit），避免明文落盘；
/// - 上次成功连接的配置 ID 存入 `UserDefaults`，下次打开时自动重连。
enum DatabaseConnectionStore {
    private static let configsKey = "DatabaseManager.savedConfigs"
    private static let lastSelectedKey = "DatabaseManager.lastSelectedConfigID"
    private static let keychain = KeychainStore(
        service: LumiRuntimeEnvironment.current.keychainService(
            for: "com.coffic.lumi.database-manager"
        )
    )

    // MARK: - Configs

    /// 读取已保存的配置，并从 Keychain 回填密码。
    static func loadConfigs() -> [DatabaseConfig] {
        guard let data = UserDefaults.standard.data(forKey: configsKey),
              var decoded = try? JSONDecoder().decode([DatabaseConfig].self, from: data) else {
            return []
        }
        for index in decoded.indices {
            decoded[index].password = password(for: decoded[index].id)
        }
        return decoded
    }

    /// 保存配置：密码写入 Keychain，UserDefaults 中只存脱敏后的副本。
    static func saveConfigs(_ configs: [DatabaseConfig]) {
        var sanitized = configs
        for index in sanitized.indices {
            if let password = configs[index].password, !password.isEmpty {
                keychain.set(password, forKey: passwordKey(for: configs[index].id))
            }
            sanitized[index].password = nil
        }
        if let data = try? JSONEncoder().encode(sanitized) {
            UserDefaults.standard.set(data, forKey: configsKey)
        }
    }

    /// 删除配置对应的 Keychain 密码。
    static func deletePassword(for configID: UUID) {
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

    private static func password(for configID: UUID) -> String? {
        keychain.string(forKey: passwordKey(for: configID))
    }

    private static func passwordKey(for configID: UUID) -> String {
        "connection.\(configID.uuidString)"
    }
}
