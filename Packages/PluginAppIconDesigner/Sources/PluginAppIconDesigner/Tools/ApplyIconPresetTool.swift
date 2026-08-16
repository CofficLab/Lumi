import AgentToolKit
import Foundation

public struct ApplyIconPresetTool: SuperAgentTool {
    public let name = "apply_icon_preset"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Create a new App Icon Designer document from a built-in preset."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = IconToolSupport.baseProperties(includeDocumentId: false)
        properties["presetId"] = [
            "type": "string",
            "enum": IconPresetLibrary.all.map(\.id),
            "description": "Preset id."
        ]
        properties["title"] = [
            "type": "string",
            "description": "Optional document title."
        ]
        return ["type": "object", "properties": properties, "required": ["presetId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Apply icon preset"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = IconToolSupport.language
        guard let presetId = IconToolSupport.string(arguments, "presetId"), !presetId.isEmpty else {
            return IconToolSupport.missingParameter("presetId", language: language)
        }

        guard let preset = IconPresetLibrary.preset(id: presetId) else {
            let available = IconPresetLibrary.all.map(\.id).joined(separator: ", ")
            return IconToolSupport.localized(
                language,
                en: "Error: Unknown icon preset: \(presetId). Available presets: \(available)",
                zh: "错误：未知图标预设：\(presetId)。可用预设：\(available)"
            )
        }

        let scope = try await IconToolSupport.resolveScope(arguments)
        let title = IconToolSupport.string(arguments, "title")
        let document = await MainActor.run {
            IconDocumentStore.shared.createDocument(from: preset, title: title, scope: scope)
        }
        await IconToolSupport.notify(scope: scope, documentId: document.id)

        switch language {
        case .chinese:
            return """
            已应用图标预设。
            作用域: \(scope.rawValue)
            预设ID: \(preset.id)
            文档ID: \(document.id)
            标题: \(document.title)
            图层数: \(document.layers.count)
            """
        case .english:
            return """
            Applied icon preset.
            scope=\(scope.rawValue)
            presetId: \(preset.id)
            documentId: \(document.id)
            title: \(document.title)
            layerCount: \(document.layers.count)
            """
        }
    }
}
