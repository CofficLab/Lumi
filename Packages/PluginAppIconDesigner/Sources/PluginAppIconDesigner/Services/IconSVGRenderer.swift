import Foundation

public struct IconSVGRenderer {
    public init() {}

    public func render(document: IconDocument) -> String {
        var elements: [String] = []
        elements.append("""
        <svg xmlns="http://www.w3.org/2000/svg" width="\(number(document.width))" height="\(number(document.height))" viewBox="0 0 \(number(document.width)) \(number(document.height))">
        """)

        if let background = paintValue(document.background), background != "#00000000" {
            elements.append("""
              <rect x="0" y="0" width="100%" height="100%" fill="\(escape(background))"/>
            """)
        }

        for layer in document.layers {
            elements.append(render(layer: layer, document: document))
        }

        elements.append("</svg>")
        return elements.joined(separator: "\n")
    }

    private func render(layer: IconLayer, document: IconDocument) -> String {
        let fill = paintValue(layer.fill) ?? "none"
        let opacity = clamp(layer.opacity, min: 0, max: 1)
        let stroke = strokeAttributes(layer.stroke)
        let transform = transformAttribute(layer.transform, document: document)
        let common = """
        fill="\(escape(fill))" opacity="\(number(opacity))"\(stroke)\(transform)
        """

        switch layer.shape {
        case .rectangle(let x, let y, let width, let height, let cornerRadius):
            return """
              <rect id="\(escape(layer.id))" x="\(number(x))" y="\(number(y))" width="\(number(width))" height="\(number(height))" rx="\(number(cornerRadius))" \(common)/>
            """
        case .circle(let cx, let cy, let radius):
            return """
              <circle id="\(escape(layer.id))" cx="\(number(cx))" cy="\(number(cy))" r="\(number(radius))" \(common)/>
            """
        case .triangle(let x, let y, let width, let height):
            let p1 = "\(number(x + width / 2)),\(number(y))"
            let p2 = "\(number(x + width)),\(number(y + height))"
            let p3 = "\(number(x)),\(number(y + height))"
            return """
              <polygon id="\(escape(layer.id))" points="\(p1) \(p2) \(p3)" \(common)/>
            """
        case .line(let x1, let y1, let x2, let y2):
            let lineStroke = layer.stroke ?? IconStroke(color: fill, width: 8)
            return """
              <line id="\(escape(layer.id))" x1="\(number(x1))" y1="\(number(y1))" x2="\(number(x2))" y2="\(number(y2))" fill="none" opacity="\(number(opacity))"\(strokeAttributes(lineStroke))\(transform) stroke-linecap="round"/>
            """
        }
    }

    private func paintValue(_ paint: IconPaint) -> String? {
        switch paint {
        case .color(let value):
            return value
        }
    }

    private func strokeAttributes(_ stroke: IconStroke?) -> String {
        guard let stroke else { return "" }
        return " stroke=\"\(escape(stroke.color))\" stroke-width=\"\(number(max(0, stroke.width)))\""
    }

    private func transformAttribute(_ transform: IconTransform, document: IconDocument) -> String {
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

    private func number(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.3f", value)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}
