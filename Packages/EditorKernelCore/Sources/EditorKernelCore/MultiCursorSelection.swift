import Foundation

public struct MultiCursorSelection: Hashable, Sendable {
    public var location: Int
    public var length: Int

    public var isCaret: Bool { length == 0 }
    public var upperBound: Int { location + length }

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}
