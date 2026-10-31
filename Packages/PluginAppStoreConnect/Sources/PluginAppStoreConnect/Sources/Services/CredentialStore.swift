import Foundation
import KitTestIsolation
import Security

final class CredentialStore: @unchecked Sendable {
    static let shared = CredentialStore()
    private let service = "com.coffic.lumi.appstoreconnect"

    private enum Keys {
        static let issuerID = "appStoreConnect.issuerID"
        static let keyID = "appStoreConnect.keyID"
        static let privateKey = "appStoreConnect.privateKey"
    }

    private init() {}

    func load() -> AppStoreConnectCredentials {
        AppStoreConnectCredentials(
            issuerID: string(forKey: Keys.issuerID) ?? "",
            keyID: string(forKey: Keys.keyID) ?? "",
            privateKey: string(forKey: Keys.privateKey) ?? ""
        )
    }

    func save(_ credentials: AppStoreConnectCredentials) {
        set(credentials.issuerID, forKey: Keys.issuerID)
        set(credentials.keyID, forKey: Keys.keyID)
        set(credentials.privateKey, forKey: Keys.privateKey)
    }

    func clear() {
        remove(forKey: Keys.issuerID)
        remove(forKey: Keys.keyID)
        remove(forKey: Keys.privateKey)
    }

    private func string(forKey key: String) -> String? {
        guard !key.isEmpty else { return nil }

        // 单元测试进程不读取开发者本机的真实钥匙串：
        // 1. 文件式钥匙串忽略 `kSecUseAuthenticationUI`，需要授权的条目会阻塞在
        //    无人应答的系统对话框上，表现为测试挂起；
        // 2. 即使能读到，也会让断言依赖开发者本机的凭证残留，结果不可复现。
        // 因此测试进程一律视为「无凭证」。
        guard !TestProcessDetector.isTestProcess else { return nil }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func set(_ value: String, forKey key: String) {
        guard !key.isEmpty else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            remove(forKey: key)
            return
        }

        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            _ = SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private func remove(forKey key: String) {
        guard !key.isEmpty else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        _ = SecItemDelete(query as CFDictionary)
    }
}
