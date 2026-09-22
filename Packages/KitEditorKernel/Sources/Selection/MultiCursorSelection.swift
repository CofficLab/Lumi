import Foundation

public struct MultiCursorSelection: Hashable, Sendable {
    public var location: Int
    public var length: Int

    public var isCaret: Bool { length == 0 }
    public var upperBound: Int {
        let (value, overflow) = location.addingReportingOverflow(length)
        guard overflow else { return value }
        return length >= 0 ? Int.max : Int.min
    }

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}
