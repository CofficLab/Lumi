import Foundation
import KernelCore
import KitAgentTool

public struct SetAppStoreConnectCiWorkflowEnabledTool: SuperAgentTool {
    public let name = "app_store_connect_set_ci_workflow_enabled"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Update a Xcode Cloud workflow enabled state."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Enable or disable workflow"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "workflowID": .object(["type": .string("string"), "description": .string("The ciWorkflow id.")]),
                "isEnabled": .object(["type": .string("boolean"), "description": .string("true to enable, false to disable.")])
            ]),
            "required": .array([.string("workflowID"), .string("isEnabled")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let workflowID = arguments["workflowID"]?.stringValue, !workflowID.isEmpty else {
            return "Missing or empty workflowID."
        }
        guard let isEnabled = AppStoreConnectToolSupport.parseBool(arguments["isEnabled"]) else {
            return "Missing or invalid isEnabled. Use true or false."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let workflow = try await client.updateCiWorkflowEnabled(id: workflowID, isEnabled: isEnabled)
            return "Workflow updated: id=\(workflow.id) enabled=\(workflow.isEnabled)"
        } catch {
            return "Failed to update workflow: \(error.localizedDescription)"
        }
    }
}
