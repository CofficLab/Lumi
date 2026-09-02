import Foundation
import KernelCore
import KitAgentTool

public struct ListAppStoreConnectCiWorkflowsTool: SuperAgentTool {
    public let name = "app_store_connect_list_ci_workflows"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List workflows under a Xcode Cloud product."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "List Xcode Cloud workflows"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "productID": .object([
                    "type": .string("string"),
                    "description": .string("The ciProduct id.")
                ])
            ]),
            "required": .array([.string("productID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let productID = arguments["productID"]?.stringValue, !productID.isEmpty else {
            return "Missing or empty productID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let workflows = try await client.listCiWorkflows(productID: productID)
            guard !workflows.isEmpty else { return "No workflows found for product id=\(productID)." }
            let lines = workflows.map { wf in
                "- \(wf.name) id=\(wf.id) enabled=\(wf.isEnabled) platform=\(wf.platformType)"
            }
            return (["Xcode Cloud workflows for product id=\(productID):"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list CI workflows: \(error.localizedDescription)"
        }
    }
}
