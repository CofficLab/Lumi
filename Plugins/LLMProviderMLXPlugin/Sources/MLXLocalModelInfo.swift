import Foundation

public struct LocalModelInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let size: String
    public let minRAM: Int
    public let expectedBytes: Int
    public let supportsVision: Bool
    public let supportsTools: Bool
    public let priority: Int
    public let series: String

    public init(
        id: String,
        displayName: String,
        description: String,
        size: String,
        minRAM: Int,
        expectedBytes: Int,
        supportsVision: Bool,
        supportsTools: Bool,
        priority: Int,
        series: String
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.size = size
        self.minRAM = minRAM
        self.expectedBytes = expectedBytes
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.priority = priority
        self.series = series
    }
}
