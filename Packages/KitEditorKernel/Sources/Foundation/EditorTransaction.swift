import Foundation

public struct EditorRange: Equatable, Sendable {
    public let location: Int
    public let length: Int

    public var nsRange: NSRange {
        NSRange(location: location, length: length)
    }

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}

public struct EditorSelection: Equatable, Sendable {
    public let range: EditorRange

    public init(range: EditorRange) {
        self.range = range
    }
}

public struct EditorTransaction: Equatable, Sendable {
    public struct Replacement: Equatable, Sendable {
        public let range: EditorRange
        public let text: String

        public init(range: EditorRange, text: String) {
            self.range = range
            self.text = text
        }
    }

    public let replacements: [Replacement]
    public let updatedSelections: [EditorSelection]?

    public init(
        replacements: [Replacement],
        updatedSelections: [EditorSelection]? = nil
    ) {
        self.replacements = replacements
        self.updatedSelections = updatedSelections
    }
}
