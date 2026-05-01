import Foundation
import LanguageServerProtocol

struct EditorFoldingState: Equatable {
    struct CollapsedRange: Hashable, Equatable {
        let startLine: Int
        let endLine: Int
        let kind: FoldingRangeKind?
    }

    var collapsedRanges: Set<CollapsedRange> = []

    var isEmpty: Bool { collapsedRanges.isEmpty }
}
