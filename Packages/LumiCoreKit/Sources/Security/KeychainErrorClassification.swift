import Foundation
import Security
import KeychainKit

// Re-export for backward compatibility
public func classifyKeychainReadResult(status: OSStatus, data: Data?) -> KeychainStatus {
    classifyKeychainResult(status: status, data: data)
}

/// Backward compatibility: use KeychainKit.KeychainStatus directly.
public typealias KeychainErrorClassification = KeychainStatus
