import AgentToolKit
import Foundation

public struct UpdateIconLayerTool: SuperAgentTool {
    public let name = "update_icon_layer"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "更新当前图标文档中的图层样式和变换，例如改颜色、移动、缩放、旋转、透明度。"
        case .english:
            return "Update a layer in the current icon document, including color, position, scale, rotation, and opacity."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "layerId": ["type": "string", "description": "Layer id returned by add_icon_shape."],
                "fill": ["type": "string", "description": "New fill color."],
                "opacity": ["type": "number", "description": "New opacity from 0 to 1."],
                "translateX": ["type": "number", "description": "Layer x translation."],
                "translateY": ["type": "number", "description": "Layer y translation."],
                "scale": ["type": "number", "description": "Layer scale."],
                "rotationDegrees": ["type": "number", "description": "Layer rotation in degrees around the canvas center."],
            ],
            "required": ["layerId"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Update icon layer"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let layerId = IconToolSupport.string(arguments, "layerId"), !layerId.isEmpty else {
            return "Error: Missing required 'layerId' parameter."
        }

        do {
            let document = try await MainActor.run {
                try IconDocumentStore.shared.updateLayer(id: layerId) { layer in
                    if let fill = IconToolSupport.string(arguments, "fill") {
                        layer.fill = .color(fill)
                    }
                    if let opacity = IconToolSupport.optionalDouble(arguments, "opacity") {
                        layer.opacity = opacity
                    }
                    if let translateX = IconToolSupport.optionalDouble(arguments, "translateX") {
                        layer.transform.translateX = translateX
                    }
                    if let translateY = IconToolSupport.optionalDouble(arguments, "translateY") {
                        layer.transform.translateY = translateY
                    }
                    if let scale = IconToolSupport.optionalDouble(arguments, "scale") {
                        layer.transform.scale = scale
                    }
                    if let rotationDegrees = IconToolSupport.optionalDouble(arguments, "rotationDegrees") {
                        layer.transform.rotationDegrees = rotationDegrees
                    }
                }
            }
            return """
            Updated icon layer.
            documentId: \(document.id)
            layerId: \(layerId)
            """
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return "Error: \(error.localizedDescription)"
        }
    }
}
