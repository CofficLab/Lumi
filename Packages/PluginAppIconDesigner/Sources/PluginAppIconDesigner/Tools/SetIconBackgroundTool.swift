import AgentToolKit
import Foundation

public struct SetIconBackgroundTool: SuperAgentTool {
    public let name = "set_icon_background"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "设置当前图标文档的背景颜色。"
        case .english:
            return "Set the background paint of the current icon document."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "color": ["type": "string", "description": IconToolSupport.description(language, en: "Background color, for example #111827 or #00000000.", zh: "背景颜色，例如 #111827 或 #00000000。")],
                "type": ["type": "string", "enum": ["color", "linearGradient", "radialGradient"], "description": IconToolSupport.description(language, en: "Background paint type.", zh: "背景填充类型。")],
                "colors": ["type": "array", "items": ["type": "string"], "description": IconToolSupport.description(language, en: "Gradient colors.", zh: "渐变颜色列表。")],
            ],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Set icon background"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let language = IconToolSupport.language(arguments)
        let paint = makePaint(arguments: arguments)

        do {
            let document = try await MainActor.run {
                try IconDocumentStore.shared.updateSelectedDocument { document in
                    document.background = paint
                }
            }
            return IconToolSupport.localized(
                language,
                en: """
                Updated icon background.
                documentId: \(document.id)
                """,
                zh: """
                已更新图标背景。
                文档ID: \(document.id)
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
        let colors = (arguments["colors"]?.value as? [String]) ?? []
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
