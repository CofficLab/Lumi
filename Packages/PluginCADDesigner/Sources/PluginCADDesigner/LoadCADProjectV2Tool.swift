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
            // importDocument 会生成新的项目 ID 并选中它；返回值必须报告这个副本，
            // 否则调用方拿到的是文件里未被选中的旧 ID。
            let imported = await MainActor.run {
                let imported = CADDocumentStore.shared.importDocument(document)
                CADDocumentStore.shared.setExportURL(url)
                return imported
            }
            return CADDesignerV2ToolSupport.localized(
                en: "Loaded project.\nprojectId: \(imported.id)\nname: \(imported.name)\ncomponentCount: \(imported.components.count)",
                zh: "已加载项目。\n项目ID: \(imported.id)\n名称: \(imported.name)\n组件数: \(imported.components.count)"
            )
        } catch let error as ToolExecutionError {
            throw error
        } catch {
            await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }
            throw CADDesignerV2ToolSupport.failure(error, toolName: name)
        }
    }
}
