import Foundation
import LumiCoreKit

public struct UpdateIconShapeTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "update_icon_shape",
        displayName: "Update Icon Shape",
        description: "Update geometry for a layer in the current icon document, including size, position, corner radius, text, or SF Symbol."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "layerId": ["type": "string", "description": "Layer id to update."],
                "x": ["type": "number", "description": "Rectangle/capsule/triangle/symbol/text x position."],
                "y": ["type": "number", "description": "Rectangle/capsule/triangle/symbol/text y position."],
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
                "size": ["type": "number", "description": "Symbol or text size."],
                "weight": ["type": "string", "description": "Symbol or text weight."],
                "symbolName": ["type": "string", "description": "SF Symbol name."],
                "text": ["type": "string", "description": "Text layer value."],
            ],
            "required": ["layerId"],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Update icon shape"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = IconToolSupport.language(context)
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

    private func updatedShape(_ shape: IconShape, arguments: [String: LumiJSONValue]) -> IconShape {
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
