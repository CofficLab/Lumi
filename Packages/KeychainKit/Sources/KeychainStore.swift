import Foundation
import Security

/// Secure string storage backed by the system Keychain.
///
/// Provides read/write with built-in retry for transient failures
/// (e.g., keychaind unavailability).
public final class KeychainStore: @unchecked Sendable {
    /// Default store instance with empty service - must be configured before use.
    public static let shared = KeychainStore(service: "")

    private let service: String
    private let backend: any KeychainBackend
    private let sleeper: (UInt64) -> Void

    /// Maximum retry attempts (including initial attempt).
    public static let maxTransientAttempts = 4

    public init(
        service: String,
        backend: any KeychainBackend = SystemKeychainBackend(),
        sleeper: @escaping (UInt64) -> Void = { nanoseconds in
            Thread.sleep(forTimeInterval: TimeInterval(nanoseconds) / 1_000_000_000)
        }
    ) {
        self.service = service
        self.backend = backend
        self.sleeper = sleeper
    }

    /// Read a string value from Keychain.
    public func string(forKey key: String) -> String? {
        try? stringReportingErrors(forKey: key)
    }

    /// Read a string value while preserving Keychain failures.
    ///
    /// A `nil` result means only that the item does not exist. Transient and
    /// unexpected Security framework failures are thrown with their OSStatus.
    public func stringReportingErrors(forKey key: String) throws -> String? {
        guard !key.isEmpty else { return nil }

        for attempt in 0..<Self.maxTransientAttempts {
            let result = backend.read(service: service, account: key)
            switch classifyKeychainResult(status: result.status, data: result.data) {
            case .found(let data):
                guard let value = String(data: data, encoding: .utf8) else {
                    throw KeychainStoreError.invalidStringData
                }
                return value
            case .missing:
                return nil
            case .unexpected(let status):
                if status == errSecSuccess {
                    throw KeychainStoreError.missingDataForSuccessfulRead
                }
                throw KeychainStoreError.readFailed(status)
            case .transientFailure(let status):
                // Don't sleep on last attempt
                if attempt < Self.maxTransientAttempts - 1 {
                    sleeper(Self.transientRetryDelayNanoseconds(for: attempt))
                    continue
                }
                throw KeychainStoreError.readFailed(status)
            }
        }
        return nil
    }

    /// Write a string value to Keychain.
    public func set(_ value: String, forKey key: String) {
        try? setReportingErrors(value, forKey: key)
    }

    /// Writes a string without deleting an existing item first and preserves
    /// Security framework failures for callers that need verification.
    public func setReportingErrors(_ value: String, forKey key: String) throws {
        guard !key.isEmpty else { return }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try removeReportingErrors(forKey: key)
            return
        }

        let result = backend.write(Data(trimmed.utf8), service: service, account: key)
        guard result.status == errSecSuccess else {
            throw KeychainStoreError.writeFailed(result.status)
        }
    }

    /// Remove a value from Keychain.
    public func remove(forKey key: String) {
        try? removeReportingErrors(forKey: key)
    }

    public func removeReportingErrors(forKey key: String) throws {
        guard !key.isEmpty else { return }
        let result = backend.delete(service: service, account: key)
        guard result.status == errSecSuccess || result.status == errSecItemNotFound else {
            throw KeychainStoreError.deleteFailed(result.status)
        }
    }

    /// Reads from Keychain, migrating a legacy UserDefaults value when present.
    public func loadMigratingLegacyUserDefaults(forKey key: String) -> String? {
        try? loadMigratingLegacyUserDefaultsReportingErrors(forKey: key)
    }

    /// Reads and migrates a legacy value without collapsing Keychain failures
    /// into a missing item.
    public func loadMigratingLegacyUserDefaultsReportingErrors(forKey key: String) throws -> String? {
        guard !key.isEmpty else { return nil }

        // 1. Current Keychain
        if let keychainValue = try stringReportingErrors(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !keychainValue.isEmpty {
            return keychainValue
        }

        // 2. Legacy UserDefaults (same key) → migrate to Keychain
        if let legacyUserDefaultsValue = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !legacyUserDefaultsValue.isEmpty {
            set(legacyUserDefaultsValue, forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
            return legacyUserDefaultsValue
        }

        return nil
    }

    /// Exponential backoff delay: 50ms → 100ms → 200ms...
    public static func transientRetryDelayNanoseconds(for attempt: Int) -> UInt64 {
        let milliseconds = 50 * Int(pow(2.0, Double(attempt)))
        return UInt64(milliseconds) * 1_000_000
    }
}
