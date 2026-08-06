import Foundation

/// Composite layout-cache key for one message row.
///
/// Height/parsing results are only reused when every influencing dimension
/// matches: content identity (via hash), available width, backing scale,
/// theme revision, and verbosity.
public struct AppKitRowLayoutKey: Hashable, Sendable {
    public let rowID: String
    public let contentHash: String
    public let availableWidth: CGFloat
    public let scale: CGFloat
    public let themeRevision: Int
    public let verbosity: String

    public init(
        rowID: String,
        contentHash: String,
        availableWidth: CGFloat,
        scale: CGFloat,
        themeRevision: Int,
        verbosity: String
    ) {
        self.rowID = rowID
        self.contentHash = contentHash
        self.availableWidth = availableWidth
        self.scale = scale
        self.themeRevision = themeRevision
        self.verbosity = verbosity
    }

    /// Key that ignores the row identity (used for shared content caches).
    public var contentKey: String {
        "\(contentHash)|\(availableWidth)|\(scale)|\(themeRevision)|\(verbosity)"
    }
}
