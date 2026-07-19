import Foundation
import LumiKernel

/// 保存当前项目为 .cadproj 文件。
public struct SaveCADProjectTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "cad_save_project",
        displayName: "Save CAD Project",
        description: "Save the current CAD project to a .cadproj (JSON) file at the given path."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "path": ["type": "string", "description": "Absolute output file path. Should end with .cadproj or .json."],
            ],
            "required": ["path"],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Save CAD project"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
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
            try await MainActor.run {
                guard let document = CADDocumentStore.shared.selectedDocument else {
                    throw CADDocumentStoreError.noSelectedDocument
                }
                try ProjectSaveLoadService().save(document: document, to: url)
                CADDocumentStore.shared.setExportURL(url)
            }
            switch language {
            case .chinese:
                return "项目已保存到：\(url.path)"
            case .english:
                return "Project saved to: \(url.path)"
            }
        } catch {
            await MainActor.run { CADDocumentStore.shared.setError(error.localizedDescription) }
            return CADToolSupport.error(error, language: language)
        }
    }
}
