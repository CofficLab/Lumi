import KitAgentTool
import KitCADDesigner
import Foundation

/// V2 implementation of the stable legacy `cad_load_project` tool.
public struct LoadCADProjectV2Tool: SuperAgentTool {
    public static let toolName = "cad_load_project"
    public let name = Self.toolName

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Load a CAD project from a .cadproj (JSON) file at the given path."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute input file path (.cadproj or .json)."],
            ],
            "required": ["path"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String { "Load CAD project" }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = CADDesignerV2ToolSupport.string(arguments, "path") else {
            throw CADDesignerV2ToolSupport.missingParameter("path", toolName: name)
        }

        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        do {
            let document = try ProjectSaveLoadService().load(from: url)
            await MainActor.run {
                _ = CADDocumentStore.shared.importDocument(document)
                CADDocumentStore.shared.setExportURL(url)
            }
            return CADDesignerV2ToolSupport.localized(
                en: "Loaded project.\nprojectId: \(document.id)\nname: \(document.name)\ncomponentCount: \(document.components.count)",
                zh: "已加载项目。\n项目ID: \(document.id)\n名称: \(document.name)\n组件数: \(document.components.count)"
            )
        } catch let error as ToolExecutionError {
            throw error
        } catch {
            await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }
            throw CADDesignerV2ToolSupport.failure(error, toolName: name)
        }
    }
}
