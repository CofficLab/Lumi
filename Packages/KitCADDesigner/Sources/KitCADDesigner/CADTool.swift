import Foundation

/// 绘图工具类型（文档第 3.1 节 Tool 层）。
public enum CADToolKind: String, CaseIterable, Identifiable, Sendable {
    case select
    case place
    case measure

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .select: return CADDesignerLocalization.string("Select")
        case .place: return "Place"
        case .measure: return CADDesignerLocalization.string("Measure")
        }
    }

    public var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .place: return "plus.app"
        case .measure: return "ruler"
        }
    }
}

/// 测量结果。
public struct MeasurementResult: Equatable, Sendable {
    public let fromComponentId: String
    public let toComponentId: String
    /// 两组件中心点距离（mm）。
    public let distance: Double

    public init(fromComponentId: String, toComponentId: String, distance: Double) {
        self.fromComponentId = fromComponentId
        self.toComponentId = toComponentId
        self.distance = distance
    }
}
