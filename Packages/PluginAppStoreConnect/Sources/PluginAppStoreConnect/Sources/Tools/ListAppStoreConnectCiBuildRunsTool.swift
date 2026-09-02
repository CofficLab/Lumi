import Foundation
import KernelCore
import KitAgentTool

public struct ListAppStoreConnectCiBuildRunsTool: SuperAgentTool {
    public let name = "app_store_connect_list_ci_build_runs"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List build runs for a Xcode Cloud workflow."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "List Xcode Cloud build runs"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "workflowID": .object([
                    "type": .string("string"),
                    "description": .string("The ciWorkflow id.")
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of build runs to return (default 20, max 200).")
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
        let parsedLimit = AppStoreConnectToolSupport.parseInt(arguments["limit"]) ?? 20
        let limit = min(max(parsedLimit, 1), 200)

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let runs = try await client.listCiBuildRuns(workflowID: workflowID, limit: limit)
            guard !runs.isEmpty else { return "No build runs found for workflow id=\(workflowID)." }
            let lines = runs.map { run in
                let number = run.number.map(String.init) ?? "n/a"
                let status = run.completionStatus ?? "in-progress"
                return "- run=\(number) id=\(run.id) progress=\(run.executionProgress) status=\(status)"
            }
            return (["Build runs for workflow id=\(workflowID):"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list CI build runs: \(error.localizedDescription)"
        }
    }
}
