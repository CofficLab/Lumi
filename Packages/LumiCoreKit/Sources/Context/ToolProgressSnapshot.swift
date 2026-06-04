import Foundation

public struct ToolProgressSnapshot: Sendable {
    public let totalLines: Int
    public let totalBytes: Int
    public let latestOutputPreview: String

    public init(
        totalLines: Int,
        totalBytes: Int,
        latestOutputPreview: String
    ) {
        self.totalLines = totalLines
        self.totalBytes = totalBytes
        self.latestOutputPreview = latestOutputPreview
    }
}

public typealias ToolProgressSnapshotProvider = @Sendable () async -> ToolProgressSnapshot?
