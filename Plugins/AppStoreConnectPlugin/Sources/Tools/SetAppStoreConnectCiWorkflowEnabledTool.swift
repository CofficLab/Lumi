import Foundation
import LumiKernel

struct SetAppStoreConnectCiWorkflowEnabledTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.set-ci-workflow-enabled",
        displayName: "Enable or disable workflow",
        description: "Update a Xcode Cloud workflow enabled state."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "workflowID": .object(["type": .string("string"), "description": .string("The ciWorkflow id.")]),
                "isEnabled": .object(["type": .string("boolean"), "description": .string("true to enable, false to disable.")])
            ]),
            "required": .array([.string("workflowID"), .string("isEnabled")])
        ])
    }

    func riskLevel(arguments: [String : LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .high
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let workflowID = arguments["workflowID"]?.stringValue, !workflowID.isEmpty else {
            return "Missing or empty workflowID."
        }
        guard let isEnabled = AppStoreConnectToolSupport.parseBool(arguments["isEnabled"]) else {
            return "Missing or invalid isEnabled. Use true or false."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let workflow = try await client.updateCiWorkflowEnabled(id: workflowID, isEnabled: isEnabled)
            return "Workflow updated: id=\(workflow.id) enabled=\(workflow.isEnabled)"
        } catch {
            return "Failed to update workflow: \(error.localizedDescription)"
        }
    }
}
