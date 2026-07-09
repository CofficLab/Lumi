import Foundation
import LumiCoreKit

/// 创建新的 CAD 项目。
public struct CreateCADProjectTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "cad_create_project",
        displayName: "Create CAD Project",
        description: "Create a new aluminum profile CAD project. Returns the project document id."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "name": ["type": "string", "description": "Project name."],
            ],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Create CAD project"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = CADToolSupport.language(context)
        let name = CADToolSupport.string(arguments, "name")

        let document = await MainActor.run {
            CADDocumentStore.shared.createDocument(name: name)
        }

        switch language {
        case .chinese:
            return """
            已创建 CAD 项目。
            项目ID: \(document.id)
            名称: \(document.name)
            """
        case .english:
            return """
            Created CAD project.
            projectId: \(document.id)
            name: \(document.name)
            """
        }
    }
}
