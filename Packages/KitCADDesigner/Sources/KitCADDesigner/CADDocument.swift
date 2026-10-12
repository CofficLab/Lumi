import Foundation

/// CAD 项目文档（`.cadproj` 格式，JSON，基于 Codable）。
///
/// 遵循文档第 4.8 节 Schema：version/name/created/modified/components/connections。
/// 组件用 `CADComponent` 包装型材与连接件，保证单一数组便于 UI 迭代。
public struct CADDocument: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var components: [CADComponent]
    public var connections: [ConnectionEdge]

    public init(
        schemaVersion: Int = CADDocument.currentSchemaVersion,
        id: String = UUID().uuidString,
        name: String = "Untitled Project",
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        components: [CADComponent] = [],
        connections: [ConnectionEdge] = []
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.components = components
        self.connections = connections
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name
        case createdAt = "created"
        case modifiedAt = "modified"
        case components, connections
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Untitled Project"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? createdAt
        components = try container.decodeIfPresent([CADComponent].self, forKey: .components) ?? []
        connections = try container.decodeIfPresent([ConnectionEdge].self, forKey: .connections) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(components, forKey: .components)
        try container.encode(connections, forKey: .connections)
    }

    /// 查找组件。
    public func component(id: String) -> CADComponent? {
        components.first { $0.id == id }
    }

    /// 索引下的组件。
    public func componentIndex(id: String) -> Int? {
        components.firstIndex { $0.id == id }
    }
}
