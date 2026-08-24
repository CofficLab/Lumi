import AgentToolKit
import CADDesignerPlugin
import Foundation

/// V2 implementation of the stable legacy `cad_create_project` tool.
public struct CreateCADProjectV2Tool: SuperAgentTool {
    public static let toolName = "cad_create_project"
    public let name = Self.toolName

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Create a new aluminum profile CAD project and return its document identifier."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": ["name": ["type": "string", "description": "Project name."]]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Create CAD project" }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let name = (arguments["name"]?.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = await MainActor.run { CADDocumentStore.shared.createDocument(name: name) }
        switch LanguagePreference.current {
        case .chinese:
            return "已创建 CAD 项目。\n项目ID: \(document.id)\n名称: \(document.name)"
        case .english:
            return "Created CAD project.\nprojectId: \(document.id)\nname: \(document.name)"
        }
    }
}
