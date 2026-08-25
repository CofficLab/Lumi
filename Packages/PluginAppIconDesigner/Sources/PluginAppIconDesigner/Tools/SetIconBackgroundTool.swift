import KitAgentTool
import Foundation

public struct SetIconBackgroundTool: SuperAgentTool {
    public let name = "set_icon_background"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Set the background paint of the current icon document."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = IconToolSupport.baseProperties()
        properties["color"] = ["type": "string", "description": "Background color, for example #111827 or #00000000."]
        properties["type"] = ["type": "string", "enum": ["color", "linearGradient", "radialGradient"], "description": "Background paint type."]
        properties["colors"] = ["type": "array", "items": ["type": "string"], "description": "Gradient colors."]
        return ["type": "object", "properties": properties]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Set icon background"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = IconToolSupport.language
        let paint = makePaint(arguments: arguments)

        do {
            let (document, scope) = try await IconToolSupport.resolveDocument(arguments)
            let updated = try await MainActor.run {
                try IconDocumentStore.shared.updateDocument(id: document.id, scope: scope) { document in
                    document.background = paint
                }
            }
            await IconToolSupport.notify(scope: scope, documentId: document.id)
            return IconToolSupport.localized(
                language,
                en: """
                Updated icon background.
                scope=\(scope.rawValue)
                documentId: \(updated.id)
                """,
                zh: """
                已更新图标背景。
                作用域: \(scope.rawValue)
                文档ID: \(updated.id)
                """
            )
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return IconToolSupport.error(error, language: language)
        }
    }

    private func makePaint(arguments: [String: ToolArgument]) -> IconPaint {
        let type = IconToolSupport.string(arguments, "type") ?? "color"
        let colors = IconToolSupport.stringArray(arguments, "colors")
        switch type {
        case "linearGradient":
            return .linearGradient(
                colors: colors.isEmpty ? ["#111827", "#2563eb"] : colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "radialGradient":
            return .radialGradient(
                colors: colors.isEmpty ? ["#38bdf8", "#111827"] : colors,
                center: .center,
                startRadius: 0,
                endRadius: 720
            )
        default:
            return .color(IconToolSupport.string(arguments, "color") ?? "#00000000")
        }
    }
}
