import AgentToolKit
import CADDesignerPlugin
import Foundation

/// V2 implementation of the stable legacy `cad_save_project` tool.
public struct SaveCADProjectV2Tool: SuperAgentTool {
    public static let toolName = "cad_save_project"
    public let name = Self.toolName

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Save the current CAD project to a .cadproj (JSON) file at the given path."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute output file path. Should end with .cadproj or .json."],
            ],
            "required": ["path"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Save CAD project" }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .medium }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = CADDesignerV2ToolSupport.string(arguments, "path") else {
            return CADDesignerV2ToolSupport.missingParameter("path")
        }

        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        do {
            try await MainActor.run {
                guard let document = CADDocumentStore.shared.selectedDocument else {
                    throw CADDocumentStoreError.noSelectedDocument
                }
                try ProjectSaveLoadService().save(document: document, to: url)
                CADDocumentStore.shared.setExportURL(url)
            }
            return CADDesignerV2ToolSupport.localized(
                en: "Project saved to: \(url.path)",
                zh: "项目已保存到：\(url.path)"
            )
        } catch {
            await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }
            return CADDesignerV2ToolSupport.error(error)
        }
    }
}
