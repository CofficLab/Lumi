import Foundation
import LumiKernel

public struct ApplyIconPresetTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "apply_icon_preset",
        displayName: "Apply Icon Preset",
        description: "Create a new App Icon Designer document from a built-in preset."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        var properties = IconToolSupport.baseProperties(includeDocumentId: false)
        properties["presetId"] = [
            "type": "string",
            "enum": .array(IconPresetLibrary.all.map { .string($0.id) }),
            "description": "Preset id."
        ]
        properties["title"] = [
            "type": "string",
            "description": "Optional document title."
        ]
        return ["type": "object", "properties": .object(properties), "required": ["presetId"]]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Apply icon preset"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let language = IconToolSupport.language(kernel)
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

        let scope = try await IconToolSupport.resolveScope(arguments, kernel: kernel)
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
