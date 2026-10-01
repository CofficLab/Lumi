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
            return "Keychain read failed (OSStatus \(status): \(Self.systemMessage(for: status)))"
        case .writeFailed(let status):
            return "Keychain write failed (OSStatus \(status): \(Self.systemMessage(for: status)))"
        case .deleteFailed(let status):
            return "Keychain delete failed (OSStatus \(status): \(Self.systemMessage(for: status)))"
        case .missingDataForSuccessfulRead:
            return "Keychain reported a successful read without returning item data"
        case .invalidStringData:
            return "Keychain item contains invalid UTF-8 data"
        }
    }

    /// 系统错误文案。`SecCopyErrorMessageString` 对部分状态码（如 -34018）
    /// 只返回状态码本身，等于没有信息；这里补充可操作的说明。
    private static func systemMessage(for status: OSStatus) -> String {
        switch status {
        case errSecMissingEntitlement:
            return "errSecMissingEntitlement: the app is missing a required Keychain entitlement"
                + " or its code signature changed; restarting the app usually fixes it"
        default:
            return SecCopyErrorMessageString(status, nil) as String?
                ?? "Unknown Keychain error"
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
