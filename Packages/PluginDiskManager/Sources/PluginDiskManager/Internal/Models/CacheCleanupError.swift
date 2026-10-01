import Foundation

public struct CacheCleanupError: LocalizedError, Sendable {
    public let path: String
    public let underlyingDescription: String

    public var errorDescription: String? {
        pluginLocalization.string("Failed to remove \(path): \(underlyingDescription)")
    }
}
