import Foundation
import KernelCore
import KitAgentTool

public struct ReadAppStoreConnectCiWorkflowTool: SuperAgentTool {
    public let name = "app_store_connect_read_ci_workflow"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Read a single workflow detail from Xcode Cloud."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Read Xcode Cloud workflow"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "workflowID": .object([
                    "type": .string("string"),
                    "description": .string("The ciWorkflow id.")
                ])
            ]),
            "required": .array([.string("workflowID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let workflowID = arguments["workflowID"]?.stringValue, !workflowID.isEmpty else {
            return "Missing or empty workflowID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let wf = try await client.readCiWorkflow(id: workflowID)
            return """
            Workflow detail:
            - id=\(wf.id)
            - name=\(wf.name)
            - enabled=\(wf.isEnabled)
            - clean=\(wf.clean)
            - platform=\(wf.platformType)
            - containerFilePath=\(wf.containerFilePath)
            - description=\(wf.description.isEmpty ? "(empty)" : wf.description)
            """
        } catch {
            return "Failed to read CI workflow: \(error.localizedDescription)"
        }
    }
}
