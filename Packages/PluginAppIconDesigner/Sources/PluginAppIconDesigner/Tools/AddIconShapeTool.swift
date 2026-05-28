import AgentToolKit
import Foundation

public struct AddIconShapeTool: SuperAgentTool {
    public let name = "add_icon_shape"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "向当前图标文档添加矢量图层。支持 rectangle、circle、capsule、triangle、line、symbol、text。"
        case .english:
            return "Add a vector layer to the current icon document. Supports rectangle, circle, capsule, triangle, line, symbol, and text."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "shape": [
                    "type": "string",
                    "enum": ["rectangle", "circle", "capsule", "triangle", "line", "symbol", "text"],
                    "description": IconToolSupport.description(language, en: "Shape type.", zh: "形状类型。")
                ],
                "name": ["type": "string", "description": IconToolSupport.description(language, en: "Layer name.", zh: "图层名称。")],
                "fill": ["type": "string", "description": IconToolSupport.description(language, en: "Fill color, for example #38bdf8.", zh: "填充颜色，例如 #38bdf8。")],
                "x": ["type": "number", "description": IconToolSupport.description(language, en: "Rectangle/capsule/triangle x position.", zh: "矩形/胶囊/三角形的 x 位置。")],
                "y": ["type": "number", "description": IconToolSupport.description(language, en: "Rectangle/capsule/triangle y position.", zh: "矩形/胶囊/三角形的 y 位置。")],
                "width": ["type": "number", "description": IconToolSupport.description(language, en: "Rectangle/capsule/triangle width.", zh: "矩形/胶囊/三角形宽度。")],
                "height": ["type": "number", "description": IconToolSupport.description(language, en: "Rectangle/capsule/triangle height.", zh: "矩形/胶囊/三角形高度。")],
                "cornerRadius": ["type": "number", "description": IconToolSupport.description(language, en: "Rectangle corner radius.", zh: "矩形圆角半径。")],
                "cx": ["type": "number", "description": IconToolSupport.description(language, en: "Circle center x.", zh: "圆心 x 坐标。")],
                "cy": ["type": "number", "description": IconToolSupport.description(language, en: "Circle center y.", zh: "圆心 y 坐标。")],
                "radius": ["type": "number", "description": IconToolSupport.description(language, en: "Circle radius.", zh: "圆形半径。")],
                "x1": ["type": "number", "description": IconToolSupport.description(language, en: "Line start x.", zh: "线条起点 x。")],
                "y1": ["type": "number", "description": IconToolSupport.description(language, en: "Line start y.", zh: "线条起点 y。")],
                "x2": ["type": "number", "description": IconToolSupport.description(language, en: "Line end x.", zh: "线条终点 x。")],
                "y2": ["type": "number", "description": IconToolSupport.description(language, en: "Line end y.", zh: "线条终点 y。")],
                "stroke": ["type": "string", "description": IconToolSupport.description(language, en: "Optional stroke color.", zh: "可选描边颜色。")],
                "strokeWidth": ["type": "number", "description": IconToolSupport.description(language, en: "Optional stroke width.", zh: "可选描边宽度。")],
                "opacity": ["type": "number", "description": IconToolSupport.description(language, en: "Layer opacity from 0 to 1.", zh: "图层不透明度，范围 0 到 1。")],
                "symbolName": ["type": "string", "description": IconToolSupport.description(language, en: "SF Symbol name for symbol layers.", zh: "符号图层使用的 SF Symbol 名称。")],
                "text": ["type": "string", "description": IconToolSupport.description(language, en: "Text value for text layers.", zh: "文字图层内容。")],
                "size": ["type": "number", "description": IconToolSupport.description(language, en: "Symbol or text size.", zh: "符号或文字尺寸。")],
                "weight": ["type": "string", "description": IconToolSupport.description(language, en: "Font/SF Symbol weight.", zh: "字体或 SF Symbol 字重。")],
                "shadowColor": ["type": "string", "description": IconToolSupport.description(language, en: "Optional shadow color.", zh: "可选阴影颜色。")],
                "shadowRadius": ["type": "number", "description": IconToolSupport.description(language, en: "Optional shadow radius.", zh: "可选阴影半径。")],
                "shadowX": ["type": "number", "description": IconToolSupport.description(language, en: "Optional shadow x offset.", zh: "可选阴影 x 偏移。")],
                "shadowY": ["type": "number", "description": IconToolSupport.description(language, en: "Optional shadow y offset.", zh: "可选阴影 y 偏移。")],
                "blurRadius": ["type": "number", "description": IconToolSupport.description(language, en: "Optional layer blur radius.", zh: "可选图层模糊半径。")],
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
        let language = IconToolSupport.language(arguments)
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

    private func makeLayer(shapeName: String, arguments: [String: ToolArgument]) throws -> IconLayer {
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

    private func makeStroke(arguments: [String: ToolArgument]) -> IconStroke? {
        guard let strokeColor = IconToolSupport.string(arguments, "stroke") else { return nil }
        return IconStroke(color: strokeColor, width: IconToolSupport.double(arguments, "strokeWidth", default: 1))
    }

    private func makeShadow(arguments: [String: ToolArgument]) -> IconShadow? {
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
