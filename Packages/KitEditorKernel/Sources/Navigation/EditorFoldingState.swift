import Foundation
import LanguageServerProtocol

public struct EditorFoldingState: Equatable {
    public struct CollapsedRange: Hashable, Equatable {
        public let startLine: Int
        public let endLine: Int
        public let kind: FoldingRangeKind?

        public init(startLine: Int, endLine: Int, kind: FoldingRangeKind?) {
            self.startLine = startLine
            self.endLine = endLine
            self.kind = kind
        }
    }

    public var collapsedRanges: Set<CollapsedRange> = []

    public var isEmpty: Bool { collapsedRanges.isEmpty }

    public init(collapsedRanges: Set<CollapsedRange> = []) {
        self.collapsedRanges = collapsedRanges
    }
}
