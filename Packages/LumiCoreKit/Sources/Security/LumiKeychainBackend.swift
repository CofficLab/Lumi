import Foundation
import KeychainKit

/// Lumi Keychain backend that wraps the generic KeychainBackend.
/// This adapter maintains backward compatibility for code using LumiKeychainBackend.
public struct LumiKeychainBackend: KeychainBackend {
    public init() {}

    public func read(service: String, account: String) -> KeychainResult {
        SystemKeychainBackend().read(service: service, account: account)
    }

    public func write(_ data: Data, service: String, account: String) -> KeychainResult {
        SystemKeychainBackend().write(data, service: service, account: account)
    }

    public func delete(service: String, account: String) -> KeychainResult {
        SystemKeychainBackend().delete(service: service, account: account)
    }
}
