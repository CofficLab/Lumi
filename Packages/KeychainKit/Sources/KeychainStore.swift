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
        guard !key.isEmpty else { return nil }

        for attempt in 0..<Self.maxTransientAttempts {
            let result = backend.read(service: service, account: key)
            switch classifyKeychainResult(status: result.status, data: result.data) {
            case .found(let data):
                return String(data: data, encoding: .utf8)
            case .missing, .unexpected:
                return nil
            case .transientFailure:
                // Don't sleep on last attempt
                if attempt < Self.maxTransientAttempts - 1 {
                    sleeper(Self.transientRetryDelayNanoseconds(for: attempt))
                    continue
                }
                return nil
            }
        }
        return nil
    }

    /// Write a string value to Keychain.
    public func set(_ value: String, forKey key: String) {
        guard !key.isEmpty else { return }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            remove(forKey: key)
            return
        }

        _ = backend.write(Data(trimmed.utf8), service: service, account: key)
    }

    /// Remove a value from Keychain.
    public func remove(forKey key: String) {
        guard !key.isEmpty else { return }
        _ = backend.delete(service: service, account: key)
    }

    /// Reads from Keychain, migrating a legacy UserDefaults value when present.
    public func loadMigratingLegacyUserDefaults(forKey key: String) -> String? {
        guard !key.isEmpty else { return nil }

        // 1. Current Keychain
        if let keychainValue = string(forKey: key)?
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
