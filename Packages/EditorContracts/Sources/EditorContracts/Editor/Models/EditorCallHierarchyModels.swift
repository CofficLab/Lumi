import Foundation

// MARK: - 调用层级模型（契约 V2）

/// 调用层级节点（符号）。`id` 可回传宿主请求 caller/callee。
public struct EditorCallHierarchyNode: Identifiable, Equatable, Sendable {
    public let id: UUID

    public let name: String

    public let kind: EditorDocumentSymbolKind

    public let uri: URL

    /// 符号完整范围（zero-based UTF-16）。
    public let range: EditorRange

    /// 选中范围（zero-based UTF-16）。
    public let selectionRange: EditorRange

    public init(
        id: UUID = UUID(),
        name: String,
        kind: EditorDocumentSymbolKind,
        uri: URL,
        range: EditorRange,
        selectionRange: EditorRange
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.uri = uri
        self.range = range
        self.selectionRange = selectionRange
    }

    /// 通过导航打开该符号时的目标。
    public var location: EditorLocation {
        EditorLocation(uri: uri, range: selectionRange)
    }
}

/// 调用层级边：指向一个节点，并附调用发生的位置列表。
public struct EditorCallHierarchyEdge: Identifiable, Equatable, Sendable {
    /// 边标识：`节点id#调用点路径`。
    public let id: String

    public let node: EditorCallHierarchyNode

    /// 调用发生位置（zero-based UTF-16）。
    public let callRanges: [EditorRange]

    public init(node: EditorCallHierarchyNode, callRanges: [EditorRange]) {
        self.id = "\(node.id.uuidString)#\(callRanges.map { "\($0.start.line)-\($0.start.character)" }.joined(separator: ","))"
        self.node = node
        self.callRanges = callRanges
    }
}

/// 调用层级面板状态快照。
public struct EditorCallHierarchyState: Equatable, Sendable {
    public let root: EditorCallHierarchyNode?
    public let incoming: [EditorCallHierarchyEdge]
    public let outgoing: [EditorCallHierarchyEdge]
    public let isLoading: Bool

    public init(
        root: EditorCallHierarchyNode?,
        incoming: [EditorCallHierarchyEdge],
        outgoing: [EditorCallHierarchyEdge],
        isLoading: Bool
    ) {
        self.root = root
        self.incoming = incoming
        self.outgoing = outgoing
        self.isLoading = isLoading
    }

    public static let empty = EditorCallHierarchyState(root: nil, incoming: [], outgoing: [], isLoading: false)
}
