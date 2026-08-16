import Foundation

/// 思维导图节点。扁平存储 + `parentId` 表达树结构，便于增删改与批量操作。
public struct MindMapNode: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var parentId: String?
    public var text: String
    public var note: String?
    public var color: String?
    public var collapsed: Bool

    public init(
        id: String = UUID().uuidString,
        parentId: String? = nil,
        text: String,
        note: String? = nil,
        color: String? = nil,
        collapsed: Bool = false
    ) {
        self.id = id
        self.parentId = parentId
        self.text = text
        self.note = note
        self.color = color
        self.collapsed = collapsed
    }

    enum CodingKeys: String, CodingKey {
        case id, parentId, text, note, color, collapsed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        collapsed = try c.decodeIfPresent(Bool.self, forKey: .collapsed) ?? false
    }
}

/// 思维导图布局方向。
public enum MindMapLayoutDirection: String, Codable, Equatable, Sendable, CaseIterable {
    /// 双侧（根居中，子节点左右展开）——经典思维导图。
    case bilateral
    /// 仅向右展开。
    case right
    /// 向下展开（组织架构图风格）。
    case down

    public var displayName: String {
        switch self {
        case .bilateral: MindMapLocalization.string("Bilateral")
        case .right: MindMapLocalization.string("Right")
        case .down: MindMapLocalization.string("Down")
        }
    }
}

/// 一张思维导图：扁平节点数组 + parentId 表达有根树。
public struct MindMap: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var title: String
    public var nodes: [MindMapNode]
    public var layoutDirection: MindMapLayoutDirection
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = MindMap.currentSchemaVersion,
        id: String = UUID().uuidString,
        title: String = "Untitled Mind Map",
        nodes: [MindMapNode] = [],
        layoutDirection: MindMapLayoutDirection = .bilateral,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.nodes = nodes
        self.layoutDirection = layoutDirection
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, title, nodes, layoutDirection, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Mind Map"
        nodes = try c.decodeIfPresent([MindMapNode].self, forKey: .nodes) ?? []
        layoutDirection = try c.decodeIfPresent(MindMapLayoutDirection.self, forKey: .layoutDirection) ?? .bilateral
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    // MARK: - Tree Helpers (read-only)

    /// 根节点（parentId 为 nil 的节点）。规整数据应有且仅有一个。
    public var root: MindMapNode? {
        nodes.first { $0.parentId == nil }
    }

    public func node(id: String) -> MindMapNode? {
        nodes.first { $0.id == id }
    }

    public func children(of parentId: String) -> [MindMapNode] {
        nodes.filter { $0.parentId == parentId }
    }

    public func children(ofParentId parentId: String?) -> [MindMapNode] {
        nodes.filter { $0.parentId == parentId }
    }

    /// 递归收集 `nodeId` 的全部后代 id（不含自身）。
    public func descendantIds(of nodeId: String) -> Set<String> {
        var result: Set<String> = []
        var stack = children(of: nodeId).map(\.id)
        while let current = stack.popLast() {
            if result.insert(current).inserted {
                stack.append(contentsOf: children(of: current).map(\.id))
            }
        }
        return result
    }

    /// 是否会形成环：把 `nodeId` 挂到 `newParentId` 下是否合法（newParentId 不能是 nodeId 自身或其后代）。
    public func wouldCreateCycle(nodeId: String, newParentId: String?) -> Bool {
        guard let newParentId else { return false } // 挂成根总是合法（单根场景除外）
        if nodeId == newParentId { return true }
        return descendantIds(of: nodeId).contains(newParentId)
    }
}
