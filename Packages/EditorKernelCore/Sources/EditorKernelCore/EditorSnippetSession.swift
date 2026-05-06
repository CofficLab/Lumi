import Foundation

public struct EditorSnippetSession: Equatable, Sendable {
    public struct PlaceholderGroup: Equatable, Sendable {
        public let index: Int
        public let ranges: [NSRange]

        public init(index: Int, ranges: [NSRange]) {
            self.index = index
            self.ranges = ranges
        }
    }

    public var groups: [PlaceholderGroup]
    public var activeGroupIndex: Int
    public var exitSelection: NSRange

    public var currentGroup: PlaceholderGroup? {
        guard groups.indices.contains(activeGroupIndex) else { return nil }
        return groups[activeGroupIndex]
    }

    public init(groups: [PlaceholderGroup], activeGroupIndex: Int, exitSelection: NSRange) {
        self.groups = groups
        self.activeGroupIndex = activeGroupIndex
        self.exitSelection = exitSelection
    }
}
