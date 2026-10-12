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
    ///
    /// - Parameter allowInteraction: 是否允许系统弹出授权/解锁 UI（如要求
    ///   用户输入登录钥匙串密码）。后台进程、无界面 agent 与自动触发路径
    ///   必须传 `false`，否则读取会阻塞在无人应答的系统对话框上。
    func read(service: String, account: String, allowInteraction: Bool) -> KeychainResult

    /// Write data to Keychain.
    @discardableResult
    func write(_ data: Data, service: String, account: String) -> KeychainResult

    /// Delete data from Keychain.
    @discardableResult
    func delete(service: String, account: String) -> KeychainResult
}

public extension KeychainBackend {
    /// 默认允许交互读取，保持既有调用点行为不变。
    func read(service: String, account: String) -> KeychainResult {
        read(service: service, account: account, allowInteraction: true)
    }
}

/// System Keychain backend using Security framework.
public struct SystemKeychainBackend: KeychainBackend {
    /// SecItem 的 legacy 路径（`SecItemCopyMatching_osx`）内部维护基于
    /// `NSThread` 的每线程状态，在 Swift concurrency 协作线程池上调用会
    /// 触发 `EXC_BREAKPOINT`。统一移到专用 GCD 串行队列执行以规避。
    private static let queue = DispatchQueue(label: "com.coffic.lumi.keychain")

    private let useDataProtectionKeychain: Bool

    public init(useDataProtectionKeychain: Bool = false) {
        self.useDataProtectionKeychain = useDataProtectionKeychain
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if useDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    public func read(service: String, account: String, allowInteraction: Bool) -> KeychainResult {
        Self.queue.sync {
            var query = baseQuery(service: service, account: account)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            if !allowInteraction {
                // 无提示模式：需要用户授权的条目直接返回
                // errSecInteractionNotAllowed，而不是弹出系统密码框。
                // headless/后台进程必须走这条路径，否则读取会一直阻塞。
                query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
            }

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
            let lookupQuery = baseQuery(service: service, account: account)

            let updateStatus = SecItemUpdate(
                lookupQuery as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            if updateStatus == errSecSuccess {
                return KeychainResult(status: updateStatus, data: data)
            }
            guard updateStatus == errSecItemNotFound else {
                return KeychainResult(status: updateStatus, data: nil)
            }

            var query = baseQuery(service: service, account: account)
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

            let status = SecItemAdd(query as CFDictionary, nil)
            return KeychainResult(status: status, data: data)
        }
    }

    public func delete(service: String, account: String) -> KeychainResult {
        Self.queue.sync {
            let query = baseQuery(service: service, account: account)

            let status = SecItemDelete(query as CFDictionary)
            return KeychainResult(status: status, data: nil)
        }
    }
}
