import Foundation
import Security

/// Keychain 底层读取结果。
///
/// 保留原始 `OSStatus`（而非直接返回 `String?`），是为了让上层能区分
/// 「项不存在」与「钥匙串瞬时不可用」两种本质不同的情况——
/// 后者在 `securityd` 抖动、睡眠唤醒、切换用户时发生，重试即可恢复。
public struct LumiKeychainReadResult: Sendable, Equatable {
    public let data: Data?
    public let status: OSStatus

    public init(data: Data?, status: OSStatus) {
        self.data = data
        self.status = status
    }
}

/// Keychain 存储后端抽象。
///
/// 引入这一层是为了可测试性：`LumiAPIKeyStore` 的读写重试逻辑可以脱离真实 Keychain，
/// 用一个注入的 mock 后端来验证「瞬时失败 → 重试 → 成功」等行为。
/// 生产环境使用 `SystemKeychainBackend`，它薄封装 `SecItem*` 系列调用。
public protocol LumiKeychainBackend: Sendable {
    /// 读取指定 service/account 下的项，返回原始 OSStatus 与（成功时的）数据。
    func read(service: String, account: String) -> LumiKeychainReadResult

    /// 写入（update 或 add）指定 service/account 下的项，返回 OSStatus。
    func write(_ data: Data, service: String, account: String) -> OSStatus

    /// 删除指定 service/account 下的项，返回 OSStatus。
    func delete(service: String, account: String) -> OSStatus
}

/// 基于 macOS Security 框架的生产实现。
///
/// `accessible` 决定 item 的可访问性属性，默认 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// （首次解锁后可读、不跨设备同步），与历史行为保持一致。
public struct SystemKeychainBackend: LumiKeychainBackend {
    // `CFString` 未声明 Sendable，但此处只持有全局常量（如 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`），
    // 运行时不可变，跨线程共享安全。
    private nonisolated(unsafe) let accessible: CFString

    public init(accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly) {
        self.accessible = accessible
    }

    public func read(service: String, account: String) -> LumiKeychainReadResult {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return LumiKeychainReadResult(data: result as? Data, status: status)
    }

    public func write(_ data: Data, service: String, account: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = accessible
            return SecItemAdd(addQuery as CFDictionary, nil)
        }
        return updateStatus
    }

    public func delete(service: String, account: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        return SecItemDelete(query as CFDictionary)
    }
}
