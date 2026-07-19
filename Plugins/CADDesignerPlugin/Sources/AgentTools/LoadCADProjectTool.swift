import Foundation
import LumiKernel

/// 从 .cadproj 文件加载项目。
public struct LoadCADProjectTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "cad_load_project",
        displayName: "Load CAD Project",
        description: "Load a CAD project from a .cadproj (JSON) file at the given path."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute input file path (.cadproj or .json)."],
            ],
            "required": ["path"],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Load CAD project"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = CADToolSupport.language(context)
        guard let path = CADToolSupport.string(arguments, "path") else {
            return CADToolSupport.missingParameter("path", language: language)
        }

        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        if !context.isPathAllowed(url.path) {
            return CADToolSupport.localized(
                language,
                en: "Error: Path is not allowed: \(url.path)",
                zh: "错误：路径不被允许：\(url.path)"
            )
        }

        do {
            let document = try ProjectSaveLoadService().load(from: url)
            await MainActor.run {
                _ = CADDocumentStore.shared.importDocument(document)
                CADDocumentStore.shared.setExportURL(url)
            }
            switch language {
            case .chinese:
                return """
                已加载项目。
                项目ID: \(document.id)
                名称: \(document.name)
                组件数: \(document.components.count)
                """
            case .english:
                return """
                Loaded project.
                projectId: \(document.id)
                name: \(document.name)
                componentCount: \(document.components.count)
                """
            }
        } catch {
            await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }
            return CADToolSupport.error(error, language: language)
        }
    }
}
