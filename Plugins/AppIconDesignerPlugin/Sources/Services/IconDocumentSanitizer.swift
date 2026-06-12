import Foundation

public enum IconDocumentSanitizer {
    public static let minimumCanvasSize = 16.0
    public static let maximumCanvasSize = 4096.0
    public static let maximumLayerCount = 256

    public static func sanitized(_ document: IconDocument) -> IconDocument {
        var sanitized = document
        sanitized.schemaVersion = IconDocument.currentSchemaVersion
        sanitized.id = nonEmpty(document.id, fallback: UUID().uuidString)
        sanitized.title = nonEmpty(document.title, fallback: "Untitled Icon")
        sanitized.width = finite(document.width, fallback: 1024).clamped(to: minimumCanvasSize...maximumCanvasSize)
        sanitized.height = finite(document.height, fallback: 1024).clamped(to: minimumCanvasSize...maximumCanvasSize)
        sanitized.background = sanitizedPaint(document.background)
        sanitized.layers = Array(document.layers.prefix(maximumLayerCount)).map(sanitizedLayer)
        return sanitized
    }

    public static func sanitizedLayer(_ layer: IconLayer) -> IconLayer {
        var sanitized = layer
        sanitized.id = nonEmpty(layer.id, fallback: UUID().uuidString)
        sanitized.name = nonEmpty(layer.name, fallback: "Layer")
        sanitized.shape = sanitizedShape(layer.shape)
        sanitized.fill = sanitizedPaint(layer.fill)
        sanitized.stroke = layer.stroke.map(sanitizedStroke)
        sanitized.opacity = finite(layer.opacity, fallback: 1).clamped(to: 0...1)
        sanitized.transform = sanitizedTransform(layer.transform)
        sanitized.shadow = layer.shadow.map(sanitizedShadow)
        sanitized.blurRadius = finite(layer.blurRadius, fallback: 0).clamped(to: 0...128)
        return sanitized
    }

    public static func sanitizedPaint(_ paint: IconPaint) -> IconPaint {
        switch paint {
        case .color(let color):
            return .color(IconColorHex.normalized(color, fallback: "#00000000"))
        case .linearGradient(let colors, let startPoint, let endPoint):
            return .linearGradient(
                colors: sanitizedGradientColors(colors),
                startPoint: sanitizedUnitPoint(startPoint),
                endPoint: sanitizedUnitPoint(endPoint)
            )
        case .radialGradient(let colors, let center, let startRadius, let endRadius):
            let sanitizedStart = finite(startRadius, fallback: 0).clamped(to: 0...4096)
            let sanitizedEnd = max(
                sanitizedStart,
                finite(endRadius, fallback: 1024).clamped(to: 0...4096)
            )
            return .radialGradient(
                colors: sanitizedGradientColors(colors),
                center: sanitizedUnitPoint(center),
                startRadius: sanitizedStart,
                endRadius: sanitizedEnd
            )
        }
    }

    private static func sanitizedShape(_ shape: IconShape) -> IconShape {
        switch shape {
        case .rectangle(let x, let y, let width, let height, let cornerRadius):
            let safeWidth = positiveSize(width)
            let safeHeight = positiveSize(height)
            return .rectangle(
                x: coordinate(x),
                y: coordinate(y),
                width: safeWidth,
                height: safeHeight,
                cornerRadius: finite(cornerRadius, fallback: 0).clamped(to: 0...min(safeWidth, safeHeight) / 2)
            )
        case .circle(let cx, let cy, let radius):
            return .circle(cx: coordinate(cx), cy: coordinate(cy), radius: positiveSize(radius))
        case .capsule(let x, let y, let width, let height):
            return .capsule(x: coordinate(x), y: coordinate(y), width: positiveSize(width), height: positiveSize(height))
        case .triangle(let x, let y, let width, let height):
            return .triangle(x: coordinate(x), y: coordinate(y), width: positiveSize(width), height: positiveSize(height))
        case .line(let x1, let y1, let x2, let y2):
            return .line(x1: coordinate(x1), y1: coordinate(y1), x2: coordinate(x2), y2: coordinate(y2))
        case .symbol(let name, let x, let y, let size, let weight):
            return .symbol(
                name: nonEmpty(name, fallback: "app"),
                x: coordinate(x),
                y: coordinate(y),
                size: positiveSize(size),
                weight: sanitizedWeight(weight)
            )
        case .text(let value, let x, let y, let size, let weight):
            return .text(
                value: String(nonEmpty(value, fallback: "A").prefix(32)),
                x: coordinate(x),
                y: coordinate(y),
                size: positiveSize(size),
                weight: sanitizedWeight(weight)
            )
        }
    }

    private static func sanitizedStroke(_ stroke: IconStroke) -> IconStroke {
        IconStroke(
            color: IconColorHex.normalized(stroke.color, fallback: "#000000"),
            width: finite(stroke.width, fallback: 1).clamped(to: 0...256)
        )
    }

    private static func sanitizedTransform(_ transform: IconTransform) -> IconTransform {
        IconTransform(
            translateX: coordinate(transform.translateX),
            translateY: coordinate(transform.translateY),
            scale: finite(transform.scale, fallback: 1).clamped(to: 0.01...64),
            rotationDegrees: finite(transform.rotationDegrees, fallback: 0).truncatingRemainder(dividingBy: 360)
        )
    }

    private static func sanitizedShadow(_ shadow: IconShadow) -> IconShadow {
        IconShadow(
            color: IconColorHex.normalized(shadow.color, fallback: "#00000040"),
            radius: finite(shadow.radius, fallback: 0).clamped(to: 0...256),
            x: coordinate(shadow.x),
            y: coordinate(shadow.y)
        )
    }

    private static func sanitizedUnitPoint(_ point: IconUnitPoint) -> IconUnitPoint {
        IconUnitPoint(
            x: finite(point.x, fallback: 0.5).clamped(to: 0...1),
            y: finite(point.y, fallback: 0.5).clamped(to: 0...1)
        )
    }

    private static func sanitizedGradientColors(_ colors: [String]) -> [String] {
        let normalized = colors.prefix(8).map {
            IconColorHex.normalized($0, fallback: "#00000000")
        }
        return normalized.isEmpty ? ["#00000000", "#00000000"] : normalized
    }

    private static func sanitizedWeight(_ value: String) -> String {
        let allowed: Set<String> = ["ultralight", "thin", "light", "regular", "medium", "semibold", "bold", "heavy", "black"]
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allowed.contains(normalized) ? normalized : "regular"
    }

    private static func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func positiveSize(_ value: Double) -> Double {
        finite(value, fallback: 1).clamped(to: 1...4096)
    }

    private static func coordinate(_ value: Double) -> Double {
        finite(value, fallback: 0).clamped(to: -4096...8192)
    }

    private static func finite(_ value: Double, fallback: Double) -> Double {
        value.isFinite ? value : fallback
    }
}

public enum IconColorHex {
    public static func normalized(_ value: String, fallback: String = "#00000000") -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard (hex.count == 6 || hex.count == 8),
              hex.unicodeScalars.allSatisfy({ CharacterSet.iconHexDigits.contains($0) })
        else {
            return fallback
        }
        return "#\(hex)"
    }
}

private extension CharacterSet {
    static let iconHexDigits = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
