import AgentToolKit
import Foundation

public struct UpdateIconShapeTool: SuperAgentTool {
    public let name = "update_icon_shape"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "更新当前图标文档里某个图层的几何参数，例如尺寸、位置、圆角、文字或 SF Symbol。"
        case .english:
            return "Update geometry for a layer in the current icon document, including size, position, corner radius, text, or SF Symbol."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "layerId": ["type": "string", "description": IconToolSupport.description(language, en: "Layer id to update.", zh: "要更新的图层 ID。")],
                "x": ["type": "number", "description": IconToolSupport.description(language, en: "Rectangle/capsule/triangle/symbol/text x position.", zh: "矩形/胶囊/三角形/符号/文字的 x 位置。")],
                "y": ["type": "number", "description": IconToolSupport.description(language, en: "Rectangle/capsule/triangle/symbol/text y position.", zh: "矩形/胶囊/三角形/符号/文字的 y 位置。")],
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
                "size": ["type": "number", "description": IconToolSupport.description(language, en: "Symbol or text size.", zh: "符号或文字尺寸。")],
                "weight": ["type": "string", "description": IconToolSupport.description(language, en: "Symbol or text weight.", zh: "符号或文字字重。")],
                "symbolName": ["type": "string", "description": IconToolSupport.description(language, en: "SF Symbol name.", zh: "SF Symbol 名称。")],
                "text": ["type": "string", "description": IconToolSupport.description(language, en: "Text layer value.", zh: "文字图层内容。")],
            ],
            "required": ["layerId"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Update icon shape"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let language = IconToolSupport.language(arguments)
        guard let layerId = IconToolSupport.string(arguments, "layerId"), !layerId.isEmpty else {
            return IconToolSupport.missingParameter("layerId", language: language)
        }

        do {
            let document = try await MainActor.run {
                try IconDocumentStore.shared.updateLayer(id: layerId) { layer in
                    layer.shape = updatedShape(layer.shape, arguments: arguments)
                }
            }
            return IconToolSupport.localized(
                language,
                en: """
                Updated icon shape.
                documentId: \(document.id)
                layerId: \(layerId)
                """,
                zh: """
                已更新图标形状。
                文档ID: \(document.id)
                图层ID: \(layerId)
                """
            )
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return IconToolSupport.error(error, language: language)
        }
    }

    private func updatedShape(_ shape: IconShape, arguments: [String: ToolArgument]) -> IconShape {
        switch shape {
        case .rectangle(let x, let y, let width, let height, let cornerRadius):
            return .rectangle(
                x: IconToolSupport.double(arguments, "x", default: x),
                y: IconToolSupport.double(arguments, "y", default: y),
                width: IconToolSupport.double(arguments, "width", default: width),
                height: IconToolSupport.double(arguments, "height", default: height),
                cornerRadius: IconToolSupport.double(arguments, "cornerRadius", default: cornerRadius)
            )
        case .circle(let cx, let cy, let radius):
            return .circle(
                cx: IconToolSupport.double(arguments, "cx", default: cx),
                cy: IconToolSupport.double(arguments, "cy", default: cy),
                radius: IconToolSupport.double(arguments, "radius", default: radius)
            )
        case .capsule(let x, let y, let width, let height):
            return .capsule(
                x: IconToolSupport.double(arguments, "x", default: x),
                y: IconToolSupport.double(arguments, "y", default: y),
                width: IconToolSupport.double(arguments, "width", default: width),
                height: IconToolSupport.double(arguments, "height", default: height)
            )
        case .triangle(let x, let y, let width, let height):
            return .triangle(
                x: IconToolSupport.double(arguments, "x", default: x),
                y: IconToolSupport.double(arguments, "y", default: y),
                width: IconToolSupport.double(arguments, "width", default: width),
                height: IconToolSupport.double(arguments, "height", default: height)
            )
        case .line(let x1, let y1, let x2, let y2):
            return .line(
                x1: IconToolSupport.double(arguments, "x1", default: x1),
                y1: IconToolSupport.double(arguments, "y1", default: y1),
                x2: IconToolSupport.double(arguments, "x2", default: x2),
                y2: IconToolSupport.double(arguments, "y2", default: y2)
            )
        case .symbol(let name, let x, let y, let size, let weight):
            return .symbol(
                name: IconToolSupport.string(arguments, "symbolName") ?? name,
                x: IconToolSupport.double(arguments, "x", default: x),
                y: IconToolSupport.double(arguments, "y", default: y),
                size: IconToolSupport.double(arguments, "size", default: size),
                weight: IconToolSupport.string(arguments, "weight") ?? weight
            )
        case .text(let value, let x, let y, let size, let weight):
            return .text(
                value: IconToolSupport.string(arguments, "text") ?? value,
                x: IconToolSupport.double(arguments, "x", default: x),
                y: IconToolSupport.double(arguments, "y", default: y),
                size: IconToolSupport.double(arguments, "size", default: size),
                weight: IconToolSupport.string(arguments, "weight") ?? weight
            )
        }
    }
}
