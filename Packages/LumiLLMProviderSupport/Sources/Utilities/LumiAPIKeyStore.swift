import Foundation
import KeychainKit

/// Lumi 各供应商共享的 API Key 存储。
///
/// 在通用的 `KeychainStore` 之上固定一个 Lumi 专属的 Keychain `service`
/// (`com.coffic.lumi.apikey`)，保证历史版本写入的 key 仍可被读到——
/// keychain 按 `(service, account)` 寻址，service 一旦改变旧数据就读不到，
/// 因此这里**不能**使用 `KeychainStore.shared`（其 service 为空）。
///
/// 所有供应商都应通过 `LumiAPIKeyTools`（或直接通过本单例）访问 key，
/// 以保证读写落同一个 service。
public final class LumiAPIKeyStore: @unchecked Sendable {
    public static let shared = LumiAPIKeyStore()

    /// 历史 keychain service，跨版本保持稳定，勿随意修改。
    static let service = "com.coffic.lumi.apikey"

    private let store: KeychainStore

    public init(store: KeychainStore? = nil) {
        self.store = store ?? KeychainStore(service: Self.service)
    }

    public func string(forKey key: String) -> String? {
        store.string(forKey: key)
    }

    public func set(_ value: String, forKey key: String) {
        store.set(value, forKey: key)
    }

    public func remove(forKey key: String) {
        store.remove(forKey: key)
    }

    /// 读取 key；若 Keychain 中缺失则尝试从同名 UserDefaults 键迁移。
    public func loadMigratingLegacyUserDefaults(forKey key: String) -> String? {
        store.loadMigratingLegacyUserDefaults(forKey: key)
    }
}
