import Foundation

/// 连接关系类型（文档第 4.5 节）。
public enum ConnectionType: String, Codable, Equatable, Sendable {
    case rigid
    case hinge
    case bolt
}

/// 型材面（用于描述连接发生在哪一面）。
public enum ProfileFace: String, Codable, Equatable, Sendable {
    case end
    case side
    case top
}

/// 装配关系图的边：两个组件间的连接关系（文档第 4.5 节）。
public struct ConnectionEdge: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var fromComponentID: String
    public var toComponentID: String
    public var connectionType: ConnectionType
    public var fromFace: ProfileFace
    public var toFace: ProfileFace

    public init(
        id: String = UUID().uuidString,
        fromComponentID: String,
        toComponentID: String,
        connectionType: ConnectionType = .rigid,
        fromFace: ProfileFace = .end,
        toFace: ProfileFace = .side
    ) {
        self.id = id
        self.fromComponentID = fromComponentID
        self.toComponentID = toComponentID
        self.connectionType = connectionType
        self.fromFace = fromFace
        self.toFace = toFace
    }
}
