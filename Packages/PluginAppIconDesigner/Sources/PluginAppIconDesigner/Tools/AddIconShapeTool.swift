import AgentToolKit
import Foundation

public struct AddIconShapeTool: SuperAgentTool {
    public let name = "add_icon_shape"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "向当前图标文档添加基础矢量形状。支持 rectangle、circle、triangle、line。"
        case .english:
            return "Add a basic vector shape to the current icon document. Supports rectangle, circle, triangle, and line."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "shape": [
                    "type": "string",
                    "enum": ["rectangle", "circle", "triangle", "line"],
                    "description": "Shape type."
                ],
                "name": ["type": "string", "description": "Layer name."],
                "fill": ["type": "string", "description": "Fill color, for example #38bdf8."],
                "x": ["type": "number", "description": "Rectangle/triangle x position."],
                "y": ["type": "number", "description": "Rectangle/triangle y position."],
                "width": ["type": "number", "description": "Rectangle/triangle width."],
                "height": ["type": "number", "description": "Rectangle/triangle height."],
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
            ],
            "required": ["shape"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Add icon shape"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let shapeName = IconToolSupport.string(arguments, "shape") else {
            return "Error: Missing required 'shape' parameter."
        }

        do {
            let layer = try makeLayer(shapeName: shapeName, arguments: arguments)
            let document = try await MainActor.run {
                try IconDocumentStore.shared.addLayer(layer)
            }
            return """
            Added icon shape.
            documentId: \(document.id)
            \(IconToolSupport.layerSummary(layer))
            layerCount: \(document.layers.count)
            """
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return "Error: \(error.localizedDescription)"
        }
    }

    private func makeLayer(shapeName: String, arguments: [String: ToolArgument]) throws -> IconLayer {
        let normalizedShape = shapeName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let fill = IconToolSupport.color(arguments, "fill", default: normalizedShape == "line" ? "#111827" : "#38bdf8")
        let name = IconToolSupport.string(arguments, "name") ?? normalizedShape.capitalized
        let opacity = IconToolSupport.double(arguments, "opacity", default: 1)
        let stroke = makeStroke(arguments: arguments)

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
                opacity: opacity
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
                opacity: opacity
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
                opacity: opacity
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
                opacity: opacity
            )
        default:
            throw AddIconShapeToolError.unsupportedShape(shapeName)
        }
    }

    private func makeStroke(arguments: [String: ToolArgument]) -> IconStroke? {
        guard let strokeColor = IconToolSupport.string(arguments, "stroke") else { return nil }
        return IconStroke(color: strokeColor, width: IconToolSupport.double(arguments, "strokeWidth", default: 1))
    }
}

private enum AddIconShapeToolError: LocalizedError {
    case unsupportedShape(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedShape(let shape):
            return "Unsupported icon shape: \(shape)"
        }
    }
}
