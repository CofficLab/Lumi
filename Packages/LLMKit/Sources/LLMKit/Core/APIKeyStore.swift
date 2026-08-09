import Foundation
import KeychainKit
import LumiKernel

/// API Key 存储。
///
/// 在通用的 `KeychainStore` 之上固定一个专属的 Keychain `service`
/// (`com.coffic.lumi.apikey`)，保证历史版本写入的 key 仍可被读到——
/// keychain 按 `(service, account)` 寻址，service 一旦改变旧数据就读不到，
/// 因此这里**不能**使用 `KeychainStore.shared`（其 service 为空）。
public final class APIKeyStore: @unchecked Sendable {
    public static let shared = APIKeyStore()

    /// 历史正式版 service；Debug 会在运行时追加独立后缀。
    static let service = "com.coffic.lumi.apikey"

    private let store: KeychainStore
    private let defaults: UserDefaults
    private let sleeper: (UInt64) -> Void

    /// Delays used only when a key that was previously confirmed as configured
    /// is unexpectedly reported as missing.
    static let missingConfirmationDelaysNanoseconds: [UInt64] = [
        50_000_000,
        100_000_000,
        200_000_000,
    ]

    public init(
        store: KeychainStore? = nil,
        defaults: UserDefaults = .standard,
        sleeper: @escaping (UInt64) -> Void = { nanoseconds in
            Thread.sleep(forTimeInterval: TimeInterval(nanoseconds) / 1_000_000_000)
        }
    ) {
        self.store = store ?? KeychainStore(
            service: LumiRuntimeEnvironment.current.keychainService(for: Self.service)
        )
        self.defaults = defaults
        self.sleeper = sleeper
    }

    public func string(forKey key: String) -> String? {
        let value = store.string(forKey: key)
        if let value, !value.isEmpty {
            markExpectedConfigured(true, forKey: key)
        }
        return value
    }

    public func set(_ value: String, forKey key: String) {
        try? setReportingErrors(value, forKey: key)
    }

    public func setReportingErrors(_ value: String, forKey key: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        try store.setReportingErrors(trimmed, forKey: key)
        markExpectedConfigured(!trimmed.isEmpty, forKey: key)
    }

    public func remove(forKey key: String) {
        try? removeReportingErrors(forKey: key)
    }

    public func removeReportingErrors(forKey key: String) throws {
        try store.removeReportingErrors(forKey: key)
        markExpectedConfigured(false, forKey: key)
    }

    /// 读取 key；若 Keychain 中缺失则尝试从同名 UserDefaults 键迁移。
    public func loadMigratingLegacyUserDefaults(forKey key: String) -> String? {
        let value = store.loadMigratingLegacyUserDefaults(forKey: key)
        if let value, !value.isEmpty {
            markExpectedConfigured(true, forKey: key)
        }
        return value
    }

    /// Reads the key while preserving Keychain access failures. A `nil` result
    /// means only that no key exists.
    public func loadMigratingLegacyUserDefaultsReportingErrors(forKey key: String) throws -> String? {
        let expectedConfigured = isExpectedConfigured(forKey: key)

        for attempt in 0...Self.missingConfirmationDelaysNanoseconds.count {
            if let value = try store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: key),
               !value.isEmpty {
                markExpectedConfigured(true, forKey: key)
                return value
            }

            guard expectedConfigured else {
                return nil
            }

            if attempt < Self.missingConfirmationDelaysNanoseconds.count {
                sleeper(Self.missingConfirmationDelaysNanoseconds[attempt])
            }
        }

        throw APIKeyStoreError.expectedItemMissing(
            account: key,
            attempts: Self.missingConfirmationDelaysNanoseconds.count + 1
        )
    }

    private func isExpectedConfigured(forKey key: String) -> Bool {
        defaults.bool(forKey: expectationDefaultsKey(for: key))
    }

    private func markExpectedConfigured(_ expected: Bool, forKey key: String) {
        defaults.set(expected, forKey: expectationDefaultsKey(for: key))
    }

    private func expectationDefaultsKey(for key: String) -> String {
        "com.coffic.lumi.apikey.expected-configured.\(key)"
    }
}

public enum APIKeyStoreError: LocalizedError, Sendable, Equatable {
    case expectedItemMissing(account: String, attempts: Int)

    public var errorDescription: String? {
        switch self {
        case .expectedItemMissing(let account, let attempts):
            return "Keychain item '\(account)' was previously configured but was reported missing after \(attempts) read attempts"
        }
    }
}
