@testable import DatabaseManagerPlugin
import Foundation
import KitKeychain
import Security
import Testing

/// 数据库连接凭据持久化的失败传播（回归 #569）。
///
/// ## 回归背景
///
/// `DatabaseConnectionStore.saveConfigs` 原先调用吞错的 `keychain.set`，无论密码是否
/// 写入成功都把脱敏配置落盘；表单随后无条件关闭。Keychain 写入失败（如锁定的
/// `errSecInteractionNotAllowed`）被静默忽略，重启后 `loadConfigs` 无法恢复密码，
/// 凭据丢失且界面毫无提示。修复：密码写入失败必须向上抛出，且不得落盘配置；
/// `addConfig`/`updateConfig` 持久化成功才更新内存列表，表单据此保留输入并报错。
@MainActor
@Suite(.serialized)
struct DatabaseConnectionCredentialPersistenceTests {

    private let configsKey = "DatabaseManager.savedConfigs"

    // MARK: - 可控 Keychain 后端

    private final class FakeKeychainStorage: @unchecked Sendable {
        var items: [String: Data] = [:]
    }

    private struct FakeKeychainBackend: KeychainBackend {
        let writeStatus: OSStatus
        let storage: FakeKeychainStorage

        func read(service: String, account: String, allowInteraction: Bool) -> KeychainResult {
            if let data = storage.items[account] {
                return KeychainResult(status: errSecSuccess, data: data)
            }
            return KeychainResult(status: errSecItemNotFound, data: nil)
        }

        func write(_ data: Data, service: String, account: String) -> KeychainResult {
            guard writeStatus == errSecSuccess else {
                return KeychainResult(status: writeStatus, data: nil)
            }
            storage.items[account] = data
            return KeychainResult(status: errSecSuccess, data: nil)
        }

        func delete(service: String, account: String) -> KeychainResult {
            storage.items.removeValue(forKey: account)
            return KeychainResult(status: errSecSuccess, data: nil)
        }
    }

    private func makeStore(writeStatus: OSStatus = errSecSuccess) -> (KeychainStore, FakeKeychainStorage) {
        let storage = FakeKeychainStorage()
        let backend = FakeKeychainBackend(writeStatus: writeStatus, storage: storage)
        let suite = UserDefaults(suiteName: "lumi-569-\(UUID().uuidString)")!
        let store = KeychainStore(service: "lumi-569-test", backend: backend, legacyUserDefaults: suite)
        return (store, storage)
    }

    private func makeConfig(password: String?) -> DatabaseConfig {
        DatabaseConfig(
            name: "pg", type: .postgresql, host: "localhost", port: 5432,
            database: "db", username: "u", password: password
        )
    }

    private func passwordKey(_ id: UUID) -> String { "connection.\(id.uuidString)" }

    private func storedConfigs() -> [DatabaseConfig] {
        guard let data = UserDefaults.standard.data(forKey: configsKey),
              let decoded = try? JSONDecoder().decode([DatabaseConfig].self, from: data) else {
            return []
        }
        return decoded
    }

    /// 隔离 UserDefaults.standard 的配置键，结束后恢复，避免污染全局状态。
    private func withIsolatedConfigs(_ body: () throws -> Void) rethrows {
        let saved = UserDefaults.standard.data(forKey: configsKey)
        UserDefaults.standard.removeObject(forKey: configsKey)
        defer {
            if let saved {
                UserDefaults.standard.set(saved, forKey: configsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: configsKey)
            }
        }
        try body()
    }

    // MARK: - 存储层：失败传播与落盘时机

    @Test("Keychain 写入失败时 saveConfigs 抛出且不落盘配置（回归 #569）")
    func saveConfigsPropagatesKeychainWriteFailureAndDoesNotPersist() throws {
        withIsolatedConfigs {
            let (store, _) = makeStore(writeStatus: errSecInteractionNotAllowed)
            let config = makeConfig(password: "secret")
            #expect(throws: KeychainStoreError.self) {
                try DatabaseConnectionStore.saveConfigs([config], keychain: store)
            }
            // 配置未被呈现为已保存。
            #expect(UserDefaults.standard.data(forKey: configsKey) == nil)
        }
    }

    @Test("Keychain 写入失败时保留此前已保存的配置（回归 #569）")
    func saveConfigsFailureKeepsPreviouslySavedConfigs() throws {
        try withIsolatedConfigs {
            let (goodStore, _) = makeStore()
            let existing = makeConfig(password: "old")
            try DatabaseConnectionStore.saveConfigs([existing], keychain: goodStore)
            #expect(storedConfigs().count == 1)

            let (badStore, _) = makeStore(writeStatus: errSecInteractionNotAllowed)
            let added = makeConfig(password: "new")
            #expect(throws: KeychainStoreError.self) {
                try DatabaseConnectionStore.saveConfigs([existing, added], keychain: badStore)
            }
            // 失败发生在落盘之前，旧配置原样保留，新配置未加入。
            let after = storedConfigs()
            #expect(after.count == 1)
            #expect(after.first?.id == existing.id)
        }
    }

    @Test("保存成功时配置脱敏落盘且密码写入 Keychain")
    func saveConfigsSuccessSanitizesPasswordAndStoresInKeychain() throws {
        try withIsolatedConfigs {
            let (store, storage) = makeStore()
            let config = makeConfig(password: "secret")
            try DatabaseConnectionStore.saveConfigs([config], keychain: store)

            let stored = storedConfigs()
            #expect(stored.count == 1)
            #expect(stored.first?.password == nil)
            #expect(storage.items[passwordKey(config.id)] == Data("secret".utf8))
        }
    }

    @Test("loadConfigs 从 Keychain 回填密码")
    func loadConfigsRestoresPasswordFromKeychain() throws {
        try withIsolatedConfigs {
            let (store, _) = makeStore()
            let config = makeConfig(password: "secret")
            try DatabaseConnectionStore.saveConfigs([config], keychain: store)

            let loaded = DatabaseConnectionStore.loadConfigs(keychain: store)
            #expect(loaded.first?.id == config.id)
            #expect(loaded.first?.password == "secret")
        }
    }

    // MARK: - 视图模型：失败时不更新内存列表

    @Test("addConfig 在 Keychain 失败时抛出且配置列表不变（回归 #569）")
    func addConfigPropagatesKeychainFailureAndKeepsConfigsUnchanged() throws {
        withIsolatedConfigs {
            let (store, _) = makeStore(writeStatus: errSecInteractionNotAllowed)
            let viewModel = DatabaseViewModel(loadSavedConfigs: false, manager: DatabaseManagerCore(), keychain: store)
            let before = viewModel.configs.map(\.id)
            let config = makeConfig(password: "secret")

            #expect(throws: KeychainStoreError.self) {
                try viewModel.addConfig(config)
            }
            #expect(viewModel.configs.map(\.id) == before)
            #expect(!viewModel.configs.contains(where: { $0.id == config.id }))
            #expect(UserDefaults.standard.data(forKey: configsKey) == nil)
        }
    }

    @Test("updateConfig 在 Keychain 失败时抛出且保留原配置（回归 #569）")
    func updateConfigPropagatesKeychainFailureAndKeepsOriginal() throws {
        withIsolatedConfigs {
            let (store, _) = makeStore(writeStatus: errSecInteractionNotAllowed)
            let viewModel = DatabaseViewModel(loadSavedConfigs: false, manager: DatabaseManagerCore(), keychain: store)
            let existing = makeConfig(password: "original")
            viewModel.configs = [existing]

            var edited = existing
            edited.name = "renamed"
            edited.password = "changed"
            #expect(throws: KeychainStoreError.self) {
                try viewModel.updateConfig(edited)
            }
            #expect(viewModel.configs.first?.password == "original")
            #expect(viewModel.configs.first?.name == existing.name)
            #expect(UserDefaults.standard.data(forKey: configsKey) == nil)
        }
    }

    @Test("addConfig 成功时追加配置并脱敏持久化")
    func addConfigSuccessAppendsAndPersists() throws {
        try withIsolatedConfigs {
            let (store, storage) = makeStore()
            let viewModel = DatabaseViewModel(loadSavedConfigs: false, manager: DatabaseManagerCore(), keychain: store)
            let config = makeConfig(password: "secret")

            try viewModel.addConfig(config)
            #expect(viewModel.configs.contains(where: { $0.id == config.id }))

            let stored = storedConfigs()
            #expect(stored.contains(where: { $0.id == config.id }))
            #expect(stored.first(where: { $0.id == config.id })?.password == nil)
            #expect(storage.items[passwordKey(config.id)] == Data("secret".utf8))
        }
    }
}