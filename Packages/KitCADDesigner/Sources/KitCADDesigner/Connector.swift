import Foundation

/// 连接件类型（文档第 4.4 节）。
public enum ConnectorKind: String, Codable, Equatable, Sendable, CaseIterable {
    case cornerBracket
    case bolt
    case nut
    case endCap
    case hinge

    public var displayName: String {
        switch self {
        case .cornerBracket: return "角码"
        case .bolt: return "螺栓"
        case .nut: return "滑块螺母"
        case .endCap: return "封端条"
        case .hinge: return "合页"
        }
    }

    public var systemImage: String {
        switch self {
        case .cornerBracket: return "square.dashed.insert"
        case .bolt: return "bolt.fill"
        case .nut: return "circle.hexagongrid.fill"
        case .endCap: return "minus.diamond.fill"
        case .hinge: return "door.left.hand.open"
        }
    }
}

/// 连接件规格。
public struct ConnectorSpec: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var kind: ConnectorKind
    /// 适配的型材系列。
    public var series: ProfileSeries
    /// 单件重量（kg）。
    public var unitWeight: Double
    public var material: String

    public init(
        id: String,
        name: String,
        kind: ConnectorKind,
        series: ProfileSeries,
        unitWeight: Double,
        material: String = "steel"
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.series = series
        self.unitWeight = unitWeight
        self.material = material
    }
}

/// 放置在场景中的连接件实例。
public struct ConnectorInstance: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var connectorId: String
    public var transform: Transform3D

    public init(
        id: String = UUID().uuidString,
        connectorId: String,
        transform: Transform3D = .identity
    ) {
        self.id = id
        self.connectorId = connectorId
        self.transform = transform
    }
}
