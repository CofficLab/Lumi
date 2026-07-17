import Foundation
import KeychainKit

/// Secure API key storage backed by the system Keychain.
///
/// Wraps `KeychainStore` with Lumi-specific service identifier and retry logic.
public final class LumiAPIKeyStore: @unchecked Sendable {
    public static let shared = LumiAPIKeyStore()

    private let store: KeychainStore

    /// Maximum retry attempts for transient Keychain failures.
    static let maxTransientAttempts = 4

    public init(store: KeychainStore? = nil) {
        // Lumi uses com.coffic.lumi.apikey as the Keychain service
        self.store = store ?? KeychainStore(service: "com.coffic.lumi.apikey")
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

    /// Reads from Keychain, migrating a legacy UserDefaults value when present.
    public func loadMigratingLegacyUserDefaults(forKey key: String) -> String? {
        store.loadMigratingLegacyUserDefaults(forKey: key)
    }
}
