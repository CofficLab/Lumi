import Foundation

/// 型材系列（欧标）。
public enum ProfileSeries: String, Codable, Equatable, Sendable, CaseIterable {
    case series20 = "20"
    case series30 = "30"
    case series40 = "40"

    public var displayName: String {
        switch self {
        case .series20: return "20 系列"
        case .series30: return "30 系列"
        case .series40: return "40 系列"
        }
    }

    /// 该系列的标准 T 槽宽度（mm）。
    public var slotWidth: Double {
        switch self {
        case .series20: return 6
        case .series30: return 8
        case .series40: return 8
        }
    }
}

/// 型材截面规格。MVP 采用参数化矩形截面 + 中央 T 槽（参考文档风险表 4.5：仅支持标准槽型截面）。
public struct ProfileSpec: Codable, Equatable, Identifiable, Sendable {
    /// 零件号，如 "profile-40x40-eu"。
    public var id: String
    public var name: String
    public var series: ProfileSeries
    /// 截面宽度（mm），即型材宽度方向尺寸。
    public var width: Double
    /// 截面高度（mm），即型材高度方向尺寸。
    public var height: Double
    /// T 槽宽度（mm）。
    public var slotWidth: Double
    /// T 槽深度（mm）。
    public var slotDepth: Double
    /// 米重（kg/m）。
    public var weightPerMeter: Double
    /// 材质，如 "6063-T5"。
    public var material: String

    public init(
        id: String,
        name: String,
        series: ProfileSeries,
        width: Double,
        height: Double,
        slotWidth: Double,
        slotDepth: Double,
        weightPerMeter: Double,
        material: String = "6063-T5"
    ) {
        self.id = id
        self.name = name
        self.series = series
        self.width = width
        self.height = height
        self.slotWidth = slotWidth
        self.slotDepth = slotDepth
        self.weightPerMeter = weightPerMeter
        self.material = material
    }

    /// 显示用的规格描述，如 "40×40"。
    public var sizeLabel: String {
        "\(Int(width))×\(Int(height))"
    }
}

/// 放置在场景中的型材实例。
public struct ProfileInstance: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    /// 关联的型材规格零件号。
    public var profileId: String
    /// 切割长度（mm），即沿 X 轴方向的拉伸长度。
    public var length: Double
    public var transform: Transform3D
    public var material: String

    public init(
        id: String = UUID().uuidString,
        profileId: String,
        length: Double,
        transform: Transform3D = .identity,
        material: String = "6063-T5"
    ) {
        self.id = id
        self.profileId = profileId
        self.length = length
        self.transform = transform
        self.material = material
    }

    /// 重量（kg），按米重 × 长度换算。
    public func weight(spec: ProfileSpec) -> Double {
        spec.weightPerMeter * (length / 1000.0)
    }
}
