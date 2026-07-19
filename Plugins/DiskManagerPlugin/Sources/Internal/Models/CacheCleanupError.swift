import Foundation
import LumiKernel

public struct CacheCleanupError: LocalizedError, Sendable {
    public let path: String
    public let underlyingDescription: String

    public var errorDescription: String? {
        LumiPluginLocalization.string("Failed to remove \(path): \(underlyingDescription)", bundle: .module)
    }
}
