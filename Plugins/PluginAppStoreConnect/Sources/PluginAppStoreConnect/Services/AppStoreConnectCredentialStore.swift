import Foundation
import Security

final class AppStoreConnectCredentialStore: @unchecked Sendable {
    static let shared = AppStoreConnectCredentialStore()
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
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
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
