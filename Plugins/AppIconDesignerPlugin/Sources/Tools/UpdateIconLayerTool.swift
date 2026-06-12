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
                "layerId": ["type": "string", "description": IconToolSupport.description(language, en: "Layer id returned by add_icon_shape.", zh: "add_icon_shape 返回的图层 ID。")],
                "fill": ["type": "string", "description": IconToolSupport.description(language, en: "New fill color.", zh: "新的填充颜色。")],
                "opacity": ["type": "number", "description": IconToolSupport.description(language, en: "New opacity from 0 to 1.", zh: "新的不透明度，范围 0 到 1。")],
                "translateX": ["type": "number", "description": IconToolSupport.description(language, en: "Layer x translation.", zh: "图层 x 平移。")],
                "translateY": ["type": "number", "description": IconToolSupport.description(language, en: "Layer y translation.", zh: "图层 y 平移。")],
                "scale": ["type": "number", "description": IconToolSupport.description(language, en: "Layer scale.", zh: "图层缩放。")],
                "rotationDegrees": ["type": "number", "description": IconToolSupport.description(language, en: "Layer rotation in degrees around the canvas center.", zh: "围绕画布中心旋转的角度。")],
                "shadowColor": ["type": "string", "description": IconToolSupport.description(language, en: "Set or update layer shadow color.", zh: "设置或更新图层阴影颜色。")],
                "shadowRadius": ["type": "number", "description": IconToolSupport.description(language, en: "Set or update layer shadow radius.", zh: "设置或更新图层阴影半径。")],
                "shadowX": ["type": "number", "description": IconToolSupport.description(language, en: "Set or update layer shadow x offset.", zh: "设置或更新图层阴影 x 偏移。")],
                "shadowY": ["type": "number", "description": IconToolSupport.description(language, en: "Set or update layer shadow y offset.", zh: "设置或更新图层阴影 y 偏移。")],
                "blurRadius": ["type": "number", "description": IconToolSupport.description(language, en: "Set layer blur radius.", zh: "设置图层模糊半径。")],
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
        let language = IconToolSupport.language(arguments)
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
