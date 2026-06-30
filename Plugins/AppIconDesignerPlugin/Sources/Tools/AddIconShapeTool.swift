import Foundation
import LumiCoreKit

public struct AddIconShapeTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "add_icon_shape",
        displayName: "Add Icon Shape",
        description: "Add a vector layer to the current icon document. Supports rectangle, circle, capsule, triangle, line, symbol, and text."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "shape": [
                    "type": "string",
                    "enum": ["rectangle", "circle", "capsule", "triangle", "line", "symbol", "text"],
                    "description": "Shape type."
                ],
                "name": ["type": "string", "description": "Layer name."],
                "fill": ["type": "string", "description": "Fill color, for example #38bdf8."],
                "x": ["type": "number", "description": "Rectangle/capsule/triangle x position."],
                "y": ["type": "number", "description": "Rectangle/capsule/triangle y position."],
                "width": ["type": "number", "description": "Rectangle/capsule/triangle width."],
                "height": ["type": "number", "description": "Rectangle/capsule/triangle height."],
                "cornerRadius": ["type": "number", "description": "Rectangle corner radius."],
                "cx": ["type": "number", "description": "Circle center x."],
                "cy": ["type": "number", "description": "Circle center y."],
                "radius": ["type": "number", "description": "Circle radius."],
                "x1": ["type": "number", "description": "Line start x."],
                "y1": ["type": "number", "description": "Line start y."],
                "x2": ["type": "number", "description": "Line end x."],
                "y2": ["type": "number", "description": "Line end y."],
                "stroke": ["type": "string", "description": "Optional stroke color."],
                "strokeWidth": ["type": "number", "description": "Optional stroke width."],
                "opacity": ["type": "number", "description": "Layer opacity from 0 to 1."],
                "symbolName": ["type": "string", "description": "SF Symbol name for symbol layers."],
                "text": ["type": "string", "description": "Text value for text layers."],
                "size": ["type": "number", "description": "Symbol or text size."],
                "weight": ["type": "string", "description": "Font/SF Symbol weight."],
                "shadowColor": ["type": "string", "description": "Optional shadow color."],
                "shadowRadius": ["type": "number", "description": "Optional shadow radius."],
                "shadowX": ["type": "number", "description": "Optional shadow x offset."],
                "shadowY": ["type": "number", "description": "Optional shadow y offset."],
                "blurRadius": ["type": "number", "description": "Optional layer blur radius."],
            ],
            "required": ["shape"],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Add icon shape"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = IconToolSupport.language(context)
        guard let shapeName = IconToolSupport.string(arguments, "shape") else {
            return IconToolSupport.missingParameter("shape", language: language)
        }

        do {
            let layer = try makeLayer(shapeName: shapeName, arguments: arguments)
            let document = try await MainActor.run {
                try IconDocumentStore.shared.addLayer(layer)
            }
            switch language {
            case .chinese:
                return """
                已添加图标形状。
                文档ID: \(document.id)
                \(IconToolSupport.layerSummary(layer, language: language))
                图层数: \(document.layers.count)
                """
            case .english:
                return """
                Added icon shape.
                documentId: \(document.id)
                \(IconToolSupport.layerSummary(layer, language: language))
                layerCount: \(document.layers.count)
                """
            }
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return IconToolSupport.error(error, language: language)
        }
    }

    private func makeLayer(shapeName: String, arguments: [String: LumiJSONValue]) throws -> IconLayer {
        let normalizedShape = shapeName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let fill = IconToolSupport.color(arguments, "fill", default: normalizedShape == "line" ? "#111827" : "#38bdf8")
        let name = IconToolSupport.string(arguments, "name") ?? normalizedShape.capitalized
        let opacity = IconToolSupport.double(arguments, "opacity", default: 1)
        let stroke = makeStroke(arguments: arguments)
        let shadow = makeShadow(arguments: arguments)
        let blurRadius = IconToolSupport.double(arguments, "blurRadius", default: 0)

        switch normalizedShape {
        case "rectangle":
            return IconLayer(
                name: name,
                shape: .rectangle(
                    x: IconToolSupport.double(arguments, "x", default: 256),
                    y: IconToolSupport.double(arguments, "y", default: 256),
                    width: IconToolSupport.double(arguments, "width", default: 512),
                    height: IconToolSupport.double(arguments, "height", default: 512),
                    cornerRadius: IconToolSupport.double(arguments, "cornerRadius", default: 0)
                ),
                fill: fill,
                stroke: stroke,
                opacity: opacity,
                shadow: shadow,
                blurRadius: blurRadius
            )
        case "circle":
            return IconLayer(
                name: name,
                shape: .circle(
                    cx: IconToolSupport.double(arguments, "cx", default: 512),
                    cy: IconToolSupport.double(arguments, "cy", default: 512),
                    radius: IconToolSupport.double(arguments, "radius", default: 256)
                ),
                fill: fill,
                stroke: stroke,
                opacity: opacity,
                shadow: shadow,
                blurRadius: blurRadius
            )
        case "capsule":
            return IconLayer(
                name: name,
                shape: .capsule(
                    x: IconToolSupport.double(arguments, "x", default: 224),
                    y: IconToolSupport.double(arguments, "y", default: 336),
                    width: IconToolSupport.double(arguments, "width", default: 576),
                    height: IconToolSupport.double(arguments, "height", default: 352)
                ),
                fill: fill,
                stroke: stroke,
                opacity: opacity,
                shadow: shadow,
                blurRadius: blurRadius
            )
        case "triangle":
            return IconLayer(
                name: name,
                shape: .triangle(
                    x: IconToolSupport.double(arguments, "x", default: 256),
                    y: IconToolSupport.double(arguments, "y", default: 232),
                    width: IconToolSupport.double(arguments, "width", default: 512),
                    height: IconToolSupport.double(arguments, "height", default: 560)
                ),
                fill: fill,
                stroke: stroke,
                opacity: opacity,
                shadow: shadow,
                blurRadius: blurRadius
            )
        case "line":
            return IconLayer(
                name: name,
                shape: .line(
                    x1: IconToolSupport.double(arguments, "x1", default: 256),
                    y1: IconToolSupport.double(arguments, "y1", default: 512),
                    x2: IconToolSupport.double(arguments, "x2", default: 768),
                    y2: IconToolSupport.double(arguments, "y2", default: 512)
                ),
                fill: fill,
                stroke: stroke ?? IconStroke(color: (IconToolSupport.string(arguments, "fill") ?? "#111827"), width: 24),
                opacity: opacity,
                shadow: shadow,
                blurRadius: blurRadius
            )
        case "symbol":
            return IconLayer(
                name: name,
                shape: .symbol(
                    name: IconToolSupport.string(arguments, "symbolName") ?? "sparkles",
                    x: IconToolSupport.double(arguments, "x", default: 512),
                    y: IconToolSupport.double(arguments, "y", default: 512),
                    size: IconToolSupport.double(arguments, "size", default: 420),
                    weight: IconToolSupport.string(arguments, "weight") ?? "semibold"
                ),
                fill: fill,
                stroke: stroke,
                opacity: opacity,
                shadow: shadow,
                blurRadius: blurRadius
            )
        case "text":
            return IconLayer(
                name: name,
                shape: .text(
                    value: IconToolSupport.string(arguments, "text") ?? "A",
                    x: IconToolSupport.double(arguments, "x", default: 512),
                    y: IconToolSupport.double(arguments, "y", default: 512),
                    size: IconToolSupport.double(arguments, "size", default: 420),
                    weight: IconToolSupport.string(arguments, "weight") ?? "bold"
                ),
                fill: fill,
                stroke: stroke,
                opacity: opacity,
                shadow: shadow,
                blurRadius: blurRadius
            )
        default:
            throw AddIconShapeToolError.unsupportedShape(shapeName)
        }
    }

    private func makeStroke(arguments: [String: LumiJSONValue]) -> IconStroke? {
        guard let strokeColor = IconToolSupport.string(arguments, "stroke") else { return nil }
        return IconStroke(color: strokeColor, width: IconToolSupport.double(arguments, "strokeWidth", default: 1))
    }

    private func makeShadow(arguments: [String: LumiJSONValue]) -> IconShadow? {
        guard let shadowColor = IconToolSupport.string(arguments, "shadowColor") else { return nil }
        return IconShadow(
            color: shadowColor,
            radius: IconToolSupport.double(arguments, "shadowRadius", default: 24),
            x: IconToolSupport.double(arguments, "shadowX", default: 0),
            y: IconToolSupport.double(arguments, "shadowY", default: 12)
        )
    }
}

private enum AddIconShapeToolError: LocalizedError {
    case unsupportedShape(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedShape(let shape):
            return AppIconDesignerLocalization.format("Unsupported icon shape: %@", shape)
        }
    }
}
