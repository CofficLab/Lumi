import Foundation

@MainActor
public final class EditorFileTreeNode: ObservableObject, Identifiable {
    public let id: URL
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let isSymbolicLink: Bool

    @Published public var children: [EditorFileTreeNode]?
    @Published public var isExpanded = false
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    init(entry: EditorFileTreeEntry) {
        id = entry.url
        url = entry.url
        name = entry.name
        isDirectory = entry.isDirectory
        isSymbolicLink = entry.isSymbolicLink
    }

    var canExpand: Bool { isDirectory && !isSymbolicLink }
}

struct EditorFileTreeEntry: Sendable, Equatable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isSymbolicLink: Bool
}
