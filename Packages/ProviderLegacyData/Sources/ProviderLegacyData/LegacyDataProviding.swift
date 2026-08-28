import Foundation
@MainActor public protocol LegacyDataProviding: AnyObject { var legacyDataRootDirectory: URL? { get }; func hasLegacyData() -> Bool; func releaseLegacySnapshot() }
@MainActor public final class DefaultLegacyDataProviding: LegacyDataProviding { public let legacyDataRootDirectory: URL?; public init(root: URL? = nil) { legacyDataRootDirectory = root }; public func hasLegacyData() -> Bool { legacyDataRootDirectory.map { FileManager.default.fileExists(atPath: $0.path) } ?? false }; public func releaseLegacySnapshot() {} }
