import Foundation
import Security

/// Classification of Keychain operation results.
public enum KeychainStatus: Sendable {
    /// Data was found successfully.
    case found(Data)

    /// The specified item does not exist.
    case missing

    /// Transient failure (e.g., keychaind unavailable). Can retry.
    case transientFailure(OSStatus)

    /// Unexpected error.
    case unexpected(OSStatus)
}

/// A Keychain operation failed for a reason other than a missing item.
///
/// Keeping this separate from `KeychainStatus.missing` lets callers avoid
/// presenting an unavailable or locked Keychain as an unconfigured secret.
public enum KeychainStoreError: LocalizedError, Sendable, Equatable {
    case readFailed(OSStatus)
    case writeFailed(OSStatus)
    case deleteFailed(OSStatus)
    case missingDataForSuccessfulRead
    case invalidStringData

    public var errorDescription: String? {
        switch self {
        case .readFailed(let status):
            let systemMessage = SecCopyErrorMessageString(status, nil) as String?
                ?? "Unknown Keychain error"
            return "Keychain read failed (OSStatus \(status): \(systemMessage))"
        case .writeFailed(let status):
            let systemMessage = SecCopyErrorMessageString(status, nil) as String?
                ?? "Unknown Keychain error"
            return "Keychain write failed (OSStatus \(status): \(systemMessage))"
        case .deleteFailed(let status):
            let systemMessage = SecCopyErrorMessageString(status, nil) as String?
                ?? "Unknown Keychain error"
            return "Keychain delete failed (OSStatus \(status): \(systemMessage))"
        case .missingDataForSuccessfulRead:
            return "Keychain reported a successful read without returning item data"
        case .invalidStringData:
            return "Keychain item contains invalid UTF-8 data"
        }
    }
}

/// Classifies Keychain operation status into readable result.
public func classifyKeychainResult(status: OSStatus, data: Data?) -> KeychainStatus {
    switch status {
    case errSecSuccess:
        if let data = data {
            return .found(data)
        }
        return .unexpected(errSecSuccess)

    case errSecItemNotFound:
        return .missing

    // Transient failures that can be retried
    case errSecInteractionNotAllowed,
         errSecNotAvailable,
         errSecDuplicateCallback:
        return .transientFailure(status)

    default:
        return .unexpected(status)
    }
}
