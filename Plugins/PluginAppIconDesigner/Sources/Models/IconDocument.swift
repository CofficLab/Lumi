import Foundation

public struct IconDocument: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var title: String
    public var width: Double
    public var height: Double
    public var background: IconPaint
    public var layers: [IconLayer]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = IconDocument.currentSchemaVersion,
        id: String = UUID().uuidString,
        title: String = "Untitled Icon",
        width: Double = 1024,
        height: Double = 1024,
        background: IconPaint = .color("#00000000"),
        layers: [IconLayer] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.width = width
        self.height = height
        self.background = background
        self.layers = layers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case title
        case width
        case height
        case background
        case layers
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        background = try container.decode(IconPaint.self, forKey: .background)
        layers = try container.decodeIfPresent([IconLayer].self, forKey: .layers) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(background, forKey: .background)
        try container.encode(layers, forKey: .layers)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

public struct IconLayer: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var shape: IconShape
    public var fill: IconPaint
    public var stroke: IconStroke?
    public var opacity: Double
    public var transform: IconTransform
    public var shadow: IconShadow?
    public var blurRadius: Double

    public init(
        id: String = UUID().uuidString,
        name: String,
        shape: IconShape,
        fill: IconPaint,
        stroke: IconStroke? = nil,
        opacity: Double = 1,
        transform: IconTransform = IconTransform(),
        shadow: IconShadow? = nil,
        blurRadius: Double = 0
    ) {
        self.id = id
        self.name = name
        self.shape = shape
        self.fill = fill
        self.stroke = stroke
        self.opacity = opacity
        self.transform = transform
        self.shadow = shadow
        self.blurRadius = blurRadius
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case shape
        case fill
        case stroke
        case opacity
        case transform
        case shadow
        case blurRadius
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        shape = try container.decode(IconShape.self, forKey: .shape)
        fill = try container.decode(IconPaint.self, forKey: .fill)
        stroke = try container.decodeIfPresent(IconStroke.self, forKey: .stroke)
        opacity = try container.decode(Double.self, forKey: .opacity)
        transform = try container.decode(IconTransform.self, forKey: .transform)
        shadow = try container.decodeIfPresent(IconShadow.self, forKey: .shadow)
        blurRadius = try container.decodeIfPresent(Double.self, forKey: .blurRadius) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(shape, forKey: .shape)
        try container.encode(fill, forKey: .fill)
        try container.encodeIfPresent(stroke, forKey: .stroke)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(transform, forKey: .transform)
        try container.encodeIfPresent(shadow, forKey: .shadow)
        try container.encode(blurRadius, forKey: .blurRadius)
    }
}

public enum IconShape: Codable, Equatable, Sendable {
    case rectangle(x: Double, y: Double, width: Double, height: Double, cornerRadius: Double)
    case circle(cx: Double, cy: Double, radius: Double)
    case capsule(x: Double, y: Double, width: Double, height: Double)
    case triangle(x: Double, y: Double, width: Double, height: Double)
    case line(x1: Double, y1: Double, x2: Double, y2: Double)
    case symbol(name: String, x: Double, y: Double, size: Double, weight: String)
    case text(value: String, x: Double, y: Double, size: Double, weight: String)
}

public enum IconPaint: Codable, Equatable, Sendable {
    case color(String)
    case linearGradient(colors: [String], startPoint: IconUnitPoint, endPoint: IconUnitPoint)
    case radialGradient(colors: [String], center: IconUnitPoint, startRadius: Double, endRadius: Double)
}

public struct IconUnitPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let topLeading = IconUnitPoint(x: 0, y: 0)
    public static let top = IconUnitPoint(x: 0.5, y: 0)
    public static let topTrailing = IconUnitPoint(x: 1, y: 0)
    public static let leading = IconUnitPoint(x: 0, y: 0.5)
    public static let center = IconUnitPoint(x: 0.5, y: 0.5)
    public static let trailing = IconUnitPoint(x: 1, y: 0.5)
    public static let bottomLeading = IconUnitPoint(x: 0, y: 1)
    public static let bottom = IconUnitPoint(x: 0.5, y: 1)
    public static let bottomTrailing = IconUnitPoint(x: 1, y: 1)
}

public struct IconStroke: Codable, Equatable, Sendable {
    public var color: String
    public var width: Double

    public init(color: String, width: Double) {
        self.color = color
        self.width = width
    }
}

public struct IconTransform: Codable, Equatable, Sendable {
    public var translateX: Double
    public var translateY: Double
    public var scale: Double
    public var rotationDegrees: Double

    public init(
        translateX: Double = 0,
        translateY: Double = 0,
        scale: Double = 1,
        rotationDegrees: Double = 0
    ) {
        self.translateX = translateX
        self.translateY = translateY
        self.scale = scale
        self.rotationDegrees = rotationDegrees
    }
}

public struct IconShadow: Codable, Equatable, Sendable {
    public var color: String
    public var radius: Double
    public var x: Double
    public var y: Double

    public init(color: String = "#00000040", radius: Double = 24, x: Double = 0, y: Double = 12) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}
