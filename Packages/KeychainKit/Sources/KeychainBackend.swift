import Foundation
import Security

/// Keychain operation result.
public struct KeychainResult: Sendable {
    public let status: OSStatus
    public let data: Data?

    public init(status: OSStatus, data: Data?) {
        self.status = status
        self.data = data
    }
}

/// Protocol for Keychain backend implementations.
public protocol KeychainBackend: Sendable {
    /// Read data from Keychain.
    func read(service: String, account: String) -> KeychainResult

    /// Write data to Keychain.
    @discardableResult
    func write(_ data: Data, service: String, account: String) -> KeychainResult

    /// Delete data from Keychain.
    @discardableResult
    func delete(service: String, account: String) -> KeychainResult
}

/// System Keychain backend using Security framework.
public struct SystemKeychainBackend: KeychainBackend {
    /// SecItem 的 legacy 路径（`SecItemCopyMatching_osx`）内部维护基于
    /// `NSThread` 的每线程状态，在 Swift concurrency 协作线程池上调用会
    /// 触发 `EXC_BREAKPOINT`。统一移到专用 GCD 串行队列执行以规避。
    private static let queue = DispatchQueue(label: "com.coffic.lumi.keychain")

    public init() {}

    public func read(service: String, account: String) -> KeychainResult {
        Self.queue.sync {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            if status == errSecSuccess, let data = result as? Data {
                return KeychainResult(status: status, data: data)
            }
            return KeychainResult(status: status, data: nil)
        }
    }

    public func write(_ data: Data, service: String, account: String) -> KeychainResult {
        Self.queue.sync {
            // First try to delete existing item
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(deleteQuery as CFDictionary)

            // Add new item
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]

            let status = SecItemAdd(query as CFDictionary, nil)
            return KeychainResult(status: status, data: data)
        }
    }

    public func delete(service: String, account: String) -> KeychainResult {
        Self.queue.sync {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]

            let status = SecItemDelete(query as CFDictionary)
            return KeychainResult(status: status, data: nil)
        }
    }
}
