import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public enum IconSVGRendererError: LocalizedError, Equatable {
    case symbolRasterizationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .symbolRasterizationFailed(let name):
            return "Unable to rasterize SF Symbol \"\(name)\" for SVG export."
        }
    }
}

public struct IconSVGRenderer {
    public init() {}

    /// Renders the document as SVG.
    ///
    /// SF Symbols have no public vector representation, so they are rasterized
    /// and embedded as PNG. If rasterization fails the renderer throws instead
    /// of silently emitting a literal symbol name.
    public func render(document: IconDocument) async throws -> String {
        let builder = SVGSceneBuilder()
        let width = Self.number(document.width)
        let height = Self.number(document.height)

        var body: [String] = []

        if let background = builder.fillReference(
            for: document.background,
            bounds: CGRect(x: 0, y: 0, width: document.width, height: document.height)
        ) {
            body.append("""
              <rect x="0" y="0" width="100%" height="100%" fill="\(background)"/>
            """)
        }

        for layer in document.layers {
            body.append(try await builder.layerElement(layer, document: document))
        }

        var parts: [String] = [
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
            """
        ]
        if !builder.defs.isEmpty {
            parts.append("<defs>")
            parts.append(contentsOf: builder.defs)
            parts.append("</defs>")
        }
        parts.append(contentsOf: body)
        parts.append("</svg>")
        return parts.joined(separator: "\n")
    }
}

// MARK: - Scene building

private final class SVGSceneBuilder {
    private(set) var defs: [String] = []
    private var counter = 0

    func layerElement(_ layer: IconLayer, document: IconDocument) async throws -> String {
        let opacity = IconSVGRenderer.clamp(layer.opacity, min: 0, max: 1)
        let transform = IconSVGRenderer.transformAttribute(layer.transform, document: document)
        let filterAttrs = filterReference(for: layer).map { " filter=\"\($0)\"" } ?? ""
        let id = IconSVGRenderer.escape(layer.id)

        switch layer.shape {
        case .symbol(let name, let x, let y, let size, let weight):
            let data = try await IconSVGRenderer.symbolPNG(
                name: name,
                weight: weight,
                size: size,
                paint: layer.fill
            )
            let href = "data:image/png;base64,\(data.base64EncodedString())"
            return """
              <image id="\(id)" x="\(IconSVGRenderer.number(x - size / 2))" y="\(IconSVGRenderer.number(y - size / 2))" width="\(IconSVGRenderer.number(size))" height="\(IconSVGRenderer.number(size))" preserveAspectRatio="xMidYMid meet" href="\(href)" opacity="\(IconSVGRenderer.number(opacity))"\(filterAttrs)\(transform)/>
            """

        case .line(let x1, let y1, let x2, let y2):
            let lineStroke = layer.stroke ?? IconStroke(color: layer.fill.hexValue, width: 8)
            return """
              <line id="\(id)" x1="\(IconSVGRenderer.number(x1))" y1="\(IconSVGRenderer.number(y1))" x2="\(IconSVGRenderer.number(x2))" y2="\(IconSVGRenderer.number(y2))" fill="none" opacity="\(IconSVGRenderer.number(opacity))"\(IconSVGRenderer.strokeAttributes(lineStroke))\(filterAttrs)\(transform) stroke-linecap="round"/>
            """

        case .rectangle(let x, let y, let width, let height, let cornerRadius):
            return """
              <rect id="\(id)" x="\(IconSVGRenderer.number(x))" y="\(IconSVGRenderer.number(y))" width="\(IconSVGRenderer.number(width))" height="\(IconSVGRenderer.number(height))" rx="\(IconSVGRenderer.number(cornerRadius))" \(commonAttributes(layer, opacity: opacity, filterAttrs: filterAttrs, transform: transform))/>
            """

        case .circle(let cx, let cy, let radius):
            return """
              <circle id="\(id)" cx="\(IconSVGRenderer.number(cx))" cy="\(IconSVGRenderer.number(cy))" r="\(IconSVGRenderer.number(radius))" \(commonAttributes(layer, opacity: opacity, filterAttrs: filterAttrs, transform: transform))/>
            """

        case .capsule(let x, let y, let width, let height):
            return """
              <rect id="\(id)" x="\(IconSVGRenderer.number(x))" y="\(IconSVGRenderer.number(y))" width="\(IconSVGRenderer.number(width))" height="\(IconSVGRenderer.number(height))" rx="\(IconSVGRenderer.number(height / 2))" \(commonAttributes(layer, opacity: opacity, filterAttrs: filterAttrs, transform: transform))/>
            """

        case .triangle(let x, let y, let width, let height):
            let p1 = "\(IconSVGRenderer.number(x + width / 2)),\(IconSVGRenderer.number(y))"
            let p2 = "\(IconSVGRenderer.number(x + width)),\(IconSVGRenderer.number(y + height))"
            let p3 = "\(IconSVGRenderer.number(x)),\(IconSVGRenderer.number(y + height))"
            return """
              <polygon id="\(id)" points="\(p1) \(p2) \(p3)" \(commonAttributes(layer, opacity: opacity, filterAttrs: filterAttrs, transform: transform))/>
            """

        case .text(let value, let x, let y, let size, _):
            return """
              <text id="\(id)" x="\(IconSVGRenderer.number(x))" y="\(IconSVGRenderer.number(y))" text-anchor="middle" dominant-baseline="middle" font-size="\(IconSVGRenderer.number(size))" \(commonAttributes(layer, opacity: opacity, filterAttrs: filterAttrs, transform: transform))>\(IconSVGRenderer.escape(value))</text>
            """
        }
    }

    private func commonAttributes(
        _ layer: IconLayer,
        opacity: Double,
        filterAttrs: String,
        transform: String
    ) -> String {
        let fill = fillReference(for: layer.fill, bounds: IconSVGRenderer.bounds(for: layer.shape)) ?? "none"
        return """
        fill="\(fill)" opacity="\(IconSVGRenderer.number(opacity))"\(IconSVGRenderer.strokeAttributes(layer.stroke))\(filterAttrs)\(transform)
        """
    }

    // MARK: Paint

    /// Returns the value for a `fill`/`stroke` attribute, or `nil` when the paint
    /// is fully transparent.
    func fillReference(for paint: IconPaint, bounds: CGRect) -> String? {
        switch paint {
        case .color(let value):
            let normalized = IconColorHex.normalized(value)
            return IconSVGRenderer.alphaComponent(normalized) > 0 ? normalized : nil

        case .linearGradient(let colors, let startPoint, let endPoint):
            let id = nextID("linear-gradient")
            let x1 = bounds.minX + startPoint.x * bounds.width
            let y1 = bounds.minY + startPoint.y * bounds.height
            let x2 = bounds.minX + endPoint.x * bounds.width
            let y2 = bounds.minY + endPoint.y * bounds.height
            let stops = IconSVGRenderer.linearStops(colors)
            defs.append("""
              <linearGradient id="\(id)" gradientUnits="userSpaceOnUse" x1="\(IconSVGRenderer.number(x1))" y1="\(IconSVGRenderer.number(y1))" x2="\(IconSVGRenderer.number(x2))" y2="\(IconSVGRenderer.number(y2))">
            \(stops.joined(separator: "\n"))
              </linearGradient>
            """)
            return "url(#\(id))"

        case .radialGradient(let colors, let center, let startRadius, let endRadius):
            let id = nextID("radial-gradient")
            let cx = bounds.minX + center.x * bounds.width
            let cy = bounds.minY + center.y * bounds.height
            let radius = max(0.001, endRadius)
            let stops = IconSVGRenderer.radialStops(colors, startRadius: startRadius, endRadius: endRadius)
            defs.append("""
              <radialGradient id="\(id)" gradientUnits="userSpaceOnUse" cx="\(IconSVGRenderer.number(cx))" cy="\(IconSVGRenderer.number(cy))" r="\(IconSVGRenderer.number(radius))">
            \(stops.joined(separator: "\n"))
              </radialGradient>
            """)
            return "url(#\(id))"
        }
    }

    // MARK: Effects

    func filterReference(for layer: IconLayer) -> String? {
        let blurRadius = max(0, layer.blurRadius)
        guard layer.shadow != nil || blurRadius > 0 else { return nil }

        let id = nextID("filter")
        var primitives: [String] = []
        var currentResult = "SourceGraphic"

        if let shadow = layer.shadow {
            let color = IconSVGRenderer.rgbaComponents(shadow.color)
            let blur = max(0, shadow.radius) / 2
            primitives.append("    <feGaussianBlur in=\"SourceAlpha\" stdDeviation=\"\(IconSVGRenderer.number(blur))\" result=\"shadowBlur\"/>")
            primitives.append("    <feOffset in=\"shadowBlur\" dx=\"\(IconSVGRenderer.number(shadow.x))\" dy=\"\(IconSVGRenderer.number(shadow.y))\" result=\"shadowOffset\"/>")
            primitives.append("    <feFlood flood-color=\"#\(color.hex)\" flood-opacity=\"\(IconSVGRenderer.number(color.alpha))\" result=\"shadowColor\"/>")
            primitives.append("    <feComposite in=\"shadowColor\" in2=\"shadowOffset\" operator=\"in\" result=\"shadow\"/>")
            primitives.append("    <feMerge result=\"shadowed\">")
            primitives.append("      <feMergeNode in=\"shadow\"/>")
            primitives.append("      <feMergeNode in=\"SourceGraphic\"/>")
            primitives.append("    </feMerge>")
            currentResult = "shadowed"
        }

        if blurRadius > 0 {
            primitives.append("    <feGaussianBlur in=\"\(currentResult)\" stdDeviation=\"\(IconSVGRenderer.number(blurRadius / 2))\"/>")
        }

        defs.append("""
          <filter id="\(id)" x="-100%" y="-100%" width="300%" height="300%" color-interpolation-filters="sRGB">
        \(primitives.joined(separator: "\n"))
          </filter>
        """)
        return "url(#\(id))"
    }

    private func nextID(_ prefix: String) -> String {
        counter += 1
        return "\(prefix)-\(counter)"
    }
}

// MARK: - Formatting helpers

extension IconSVGRenderer {
    static func bounds(for shape: IconShape) -> CGRect {
        switch shape {
        case .rectangle(let x, let y, let width, let height, _):
            return CGRect(x: x, y: y, width: max(0, width), height: max(0, height))
        case .circle(let cx, let cy, let radius):
            return CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
        case .capsule(let x, let y, let width, let height):
            return CGRect(x: x, y: y, width: max(0, width), height: max(0, height))
        case .triangle(let x, let y, let width, let height):
            return CGRect(x: x, y: y, width: max(0, width), height: max(0, height))
        case .line(let x1, let y1, let x2, let y2):
            return CGRect(
                x: Swift.min(x1, x2),
                y: Swift.min(y1, y2),
                width: abs(x2 - x1),
                height: abs(y2 - y1)
            )
        case .symbol(_, let x, let y, let size, _):
            return CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)
        case .text(let value, let x, let y, let size, _):
            let width = max(size, Double(value.count) * size * 0.6)
            return CGRect(x: x - width / 2, y: y - size / 2, width: width, height: size)
        }
    }

    static func linearStops(_ colors: [String]) -> [String] {
        guard !colors.isEmpty else { return [] }
        if colors.count == 1 {
            return [stop(colors[0], offset: 0), stop(colors[0], offset: 1)]
        }
        return colors.enumerated().map { index, color in
            stop(color, offset: Double(index) / Double(colors.count - 1))
        }
    }

    static func radialStops(_ colors: [String], startRadius: Double, endRadius: Double) -> [String] {
        guard !colors.isEmpty else { return [] }
        if colors.count == 1 {
            return [stop(colors[0], offset: 0), stop(colors[0], offset: 1)]
        }

        let startOffset = endRadius > 0 ? clamp(startRadius / endRadius, min: 0, max: 1) : 0
        guard startOffset > 0 else {
            return colors.enumerated().map { index, color in
                stop(color, offset: Double(index) / Double(colors.count - 1))
            }
        }

        // The first color stays solid until `startRadius`; remaining colors are
        // distributed evenly between `startRadius` and `endRadius`.
        var stops = [stop(colors[0], offset: 0), stop(colors[0], offset: startOffset)]
        let tail = Array(colors.dropFirst())
        for (index, color) in tail.enumerated() {
            let t = tail.count > 1 ? Double(index) / Double(tail.count - 1) : 1
            stops.append(stop(color, offset: startOffset + (1 - startOffset) * t))
        }
        return stops
    }

    static func stop(_ color: String, offset: Double) -> String {
        let rgba = rgbaComponents(color)
        var attributes = "offset=\"\(number(clamp(offset, min: 0, max: 1)))\" stop-color=\"#\(rgba.hex)\""
        if rgba.alpha < 1 {
            attributes += " stop-opacity=\"\(number(rgba.alpha))\""
        }
        return "    <stop \(attributes)/>"
    }

    static func rgbaComponents(_ value: String) -> (hex: String, alpha: Double) {
        let digits = IconColorHex.normalized(value).dropFirst()
        if digits.count == 8 {
            let rgb = String(digits.prefix(6)).uppercased()
            let alpha = Double(UInt8(digits.suffix(2), radix: 16) ?? 255) / 255
            return (rgb, alpha)
        }
        return (String(digits).uppercased(), 1)
    }

    static func alphaComponent(_ value: String) -> Double {
        rgbaComponents(value).alpha
    }

    static func strokeAttributes(_ stroke: IconStroke?) -> String {
        guard let stroke else { return "" }
        return " stroke=\"\(escape(stroke.color))\" stroke-width=\"\(number(max(0, stroke.width)))\""
    }

    static func transformAttribute(_ transform: IconTransform, document: IconDocument) -> String {
        var transforms: [String] = []
        if transform.translateX != 0 || transform.translateY != 0 {
            transforms.append("translate(\(number(transform.translateX)) \(number(transform.translateY)))")
        }
        if transform.scale != 1 {
            transforms.append("scale(\(number(max(0.01, transform.scale))))")
        }
        if transform.rotationDegrees != 0 {
            transforms.append("rotate(\(number(transform.rotationDegrees)) \(number(document.width / 2)) \(number(document.height / 2)))")
        }
        guard !transforms.isEmpty else { return "" }
        return " transform=\"\(transforms.joined(separator: " "))\""
    }

    static func number(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.3f", value)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }

    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }

    // MARK: SF Symbol rasterization

    @MainActor
    static func symbolPNG(
        name: String,
        weight: String,
        size: Double,
        paint: IconPaint
    ) throws -> Data {
        let content = Image(systemName: name)
            .resizable()
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: size, weight: fontWeight(weight)))
            .foregroundStyle(shapeStyle(paint))
            .scaledToFit()
            .frame(width: size, height: size)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        guard let cgImage = renderer.cgImage else {
            throw IconSVGRendererError.symbolRasterizationFailed(name)
        }

        #if canImport(AppKit)
        guard let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
            throw IconSVGRendererError.symbolRasterizationFailed(name)
        }
        return data
        #elseif canImport(UIKit)
        guard let data = UIImage(cgImage: cgImage).pngData() else {
            throw IconSVGRendererError.symbolRasterizationFailed(name)
        }
        return data
        #else
        throw IconSVGRendererError.symbolRasterizationFailed(name)
        #endif
    }

    static func shapeStyle(_ paint: IconPaint) -> AnyShapeStyle {
        switch paint {
        case .color(let value):
            return AnyShapeStyle(Color(iconHex: value))
        case .linearGradient(let colors, let startPoint, let endPoint):
            return AnyShapeStyle(
                LinearGradient(
                    colors: colors.map(Color.init(iconHex:)),
                    startPoint: UnitPoint(iconPoint: startPoint),
                    endPoint: UnitPoint(iconPoint: endPoint)
                )
            )
        case .radialGradient(let colors, let center, let startRadius, let endRadius):
            return AnyShapeStyle(
                RadialGradient(
                    colors: colors.map(Color.init(iconHex:)),
                    center: UnitPoint(iconPoint: center),
                    startRadius: startRadius,
                    endRadius: endRadius
                )
            )
        }
    }

    static func fontWeight(_ value: String) -> Font.Weight {
        switch value.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }
}
