import Foundation

struct EditorSnippetSession: Equatable {
    struct PlaceholderGroup: Equatable {
        let index: Int
        let ranges: [NSRange]
    }

    var groups: [PlaceholderGroup]
    var activeGroupIndex: Int
    var exitSelection: NSRange

    var currentGroup: PlaceholderGroup? {
        guard groups.indices.contains(activeGroupIndex) else { return nil }
        return groups[activeGroupIndex]
    }
}
