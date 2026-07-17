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

/// Classifies Keychain operation status into readable result.
public func classifyKeychainResult(status: OSStatus, data: Data?) -> KeychainStatus {
    switch status {
    case errSecSuccess:
        if let data = data {
            return .found(data)
        }
        return .missing

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
