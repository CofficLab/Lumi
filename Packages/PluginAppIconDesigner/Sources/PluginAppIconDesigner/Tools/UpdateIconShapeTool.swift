import KitAgentTool
import Foundation

public struct UpdateIconShapeTool: SuperAgentTool {
    public let name = "update_icon_shape"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Update geometry for a layer in the current icon document, including size, position, corner radius, text, or SF Symbol."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = IconToolSupport.baseProperties()
        properties["layerId"] = ["type": "string", "description": "Layer id to update."]
        properties["x"] = ["type": "number", "description": "Rectangle/capsule/triangle/symbol/text x position."]
        properties["y"] = ["type": "number", "description": "Rectangle/capsule/triangle/symbol/text y position."]
        properties["width"] = ["type": "number", "description": "Rectangle/capsule/triangle width."]
        properties["height"] = ["type": "number", "description": "Rectangle/capsule/triangle height."]
        properties["cornerRadius"] = ["type": "number", "description": "Rectangle corner radius."]
        properties["cx"] = ["type": "number", "description": "Circle center x."]
        properties["cy"] = ["type": "number", "description": "Circle center y."]
        properties["radius"] = ["type": "number", "description": "Circle radius."]
        properties["x1"] = ["type": "number", "description": "Line start x."]
        properties["y1"] = ["type": "number", "description": "Line start y."]
        properties["x2"] = ["type": "number", "description": "Line end x."]
        properties["y2"] = ["type": "number", "description": "Line end y."]
        properties["size"] = ["type": "number", "description": "Symbol or text size."]
        properties["weight"] = ["type": "string", "description": "Symbol or text weight."]
        properties["symbolName"] = ["type": "string", "description": "SF Symbol name."]
        properties["text"] = ["type": "string", "description": "Text layer value."]
        return ["type": "object", "properties": properties, "required": ["layerId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Update icon shape"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = IconToolSupport.language
        guard let layerId = IconToolSupport.string(arguments, "layerId"), !layerId.isEmpty else {
            return IconToolSupport.missingParameter("layerId", language: language)
        }

        do {
            let (document, scope) = try await IconToolSupport.resolveDocument(arguments)
            let updated = try await MainActor.run {
                try IconDocumentStore.shared.updateLayer(id: layerId, documentId: document.id, scope: scope) { layer in
                    layer.shape = updatedShape(layer.shape, arguments: arguments)
                }
            }
            await IconToolSupport.notify(scope: scope, documentId: document.id)
            return IconToolSupport.localized(
                language,
                en: """
                Updated icon shape.
                scope=\(scope.rawValue)
                documentId: \(updated.id)
                layerId: \(layerId)
                """,
                zh: """
                已更新图标形状。
                作用域: \(scope.rawValue)
                文档ID: \(updated.id)
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
