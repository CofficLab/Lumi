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
            return "Set the background color of the current icon document."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "color": ["type": "string", "description": "Background color, for example #111827 or #00000000."],
            ],
            "required": ["color"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Set icon background"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let color = IconToolSupport.string(arguments, "color"), !color.isEmpty else {
            return "Error: Missing required 'color' parameter."
        }

        do {
            let document = try await MainActor.run {
                try IconDocumentStore.shared.updateSelectedDocument { document in
                    document.background = .color(color)
                }
            }
            return """
            Updated icon background.
            documentId: \(document.id)
            color: \(color)
            """
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return "Error: \(error.localizedDescription)"
        }
    }
}
