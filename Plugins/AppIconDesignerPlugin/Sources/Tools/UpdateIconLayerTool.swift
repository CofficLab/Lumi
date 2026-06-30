import Foundation
import LumiCoreKit

public struct UpdateIconLayerTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "update_icon_layer",
        displayName: "Update Icon Layer",
        description: "Update a layer in the current icon document, including color, position, scale, rotation, and opacity."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
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
                "shadowColor": ["type": "string", "description": "Set or update layer shadow color."],
                "shadowRadius": ["type": "number", "description": "Set or update layer shadow radius."],
                "shadowX": ["type": "number", "description": "Set or update layer shadow x offset."],
                "shadowY": ["type": "number", "description": "Set or update layer shadow y offset."],
                "blurRadius": ["type": "number", "description": "Set layer blur radius."],
            ],
            "required": ["layerId"],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Update icon layer"
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
                    if let blurRadius = IconToolSupport.optionalDouble(arguments, "blurRadius") {
                        layer.blurRadius = max(0, blurRadius)
                    }
                    if IconToolSupport.string(arguments, "shadowColor") != nil
                        || IconToolSupport.optionalDouble(arguments, "shadowRadius") != nil
                        || IconToolSupport.optionalDouble(arguments, "shadowX") != nil
                        || IconToolSupport.optionalDouble(arguments, "shadowY") != nil {
                        var shadow = layer.shadow ?? IconShadow()
                        if let shadowColor = IconToolSupport.string(arguments, "shadowColor") {
                            shadow.color = shadowColor
                        }
                        if let shadowRadius = IconToolSupport.optionalDouble(arguments, "shadowRadius") {
                            shadow.radius = max(0, shadowRadius)
                        }
                        if let shadowX = IconToolSupport.optionalDouble(arguments, "shadowX") {
                            shadow.x = shadowX
                        }
                        if let shadowY = IconToolSupport.optionalDouble(arguments, "shadowY") {
                            shadow.y = shadowY
                        }
                        layer.shadow = shadow
                    }
                }
            }
            return IconToolSupport.localized(
                language,
                en: """
                Updated icon layer.
                documentId: \(document.id)
                layerId: \(layerId)
                """,
                zh: """
                已更新图标图层。
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
}
