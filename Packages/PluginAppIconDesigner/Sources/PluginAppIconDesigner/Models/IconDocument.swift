import Foundation

public struct IconDocument: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var width: Double
    public var height: Double
    public var background: IconPaint
    public var layers: [IconLayer]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String = "Untitled Icon",
        width: Double = 1024,
        height: Double = 1024,
        background: IconPaint = .color("#00000000"),
        layers: [IconLayer] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.width = width
        self.height = height
        self.background = background
        self.layers = layers
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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

    public init(
        id: String = UUID().uuidString,
        name: String,
        shape: IconShape,
        fill: IconPaint,
        stroke: IconStroke? = nil,
        opacity: Double = 1,
        transform: IconTransform = IconTransform()
    ) {
        self.id = id
        self.name = name
        self.shape = shape
        self.fill = fill
        self.stroke = stroke
        self.opacity = opacity
        self.transform = transform
    }
}

public enum IconShape: Codable, Equatable, Sendable {
    case rectangle(x: Double, y: Double, width: Double, height: Double, cornerRadius: Double)
    case circle(cx: Double, cy: Double, radius: Double)
    case triangle(x: Double, y: Double, width: Double, height: Double)
    case line(x1: Double, y1: Double, x2: Double, y2: Double)
}

public enum IconPaint: Codable, Equatable, Sendable {
    case color(String)
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
