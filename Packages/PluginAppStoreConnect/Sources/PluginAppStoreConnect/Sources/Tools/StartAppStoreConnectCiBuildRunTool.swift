import Foundation
import KernelCore
import KitAgentTool

public struct StartAppStoreConnectCiBuildRunTool: SuperAgentTool {
    public let name = "app_store_connect_start_ci_build_run"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Trigger a new build run for a workflow."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Start Xcode Cloud build run"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "workflowID": .object(["type": .string("string"), "description": .string("The ciWorkflow id.")]),
                "branch": .object(["type": .string("string"), "description": .string("Optional source branch or tag.")])
            ]),
            "required": .array([.string("workflowID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let workflowID = arguments["workflowID"]?.stringValue, !workflowID.isEmpty else {
            return "Missing or empty workflowID."
        }
        let branch = arguments["branch"]?.stringValue ?? ""
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let run = try await client.startCiBuildRun(workflowID: workflowID, branch: branch)
            let number = run.number.map(String.init) ?? "n/a"
            return "Build run started: id=\(run.id) number=\(number) progress=\(run.executionProgress)"
        } catch {
            return "Failed to start CI build run: \(error.localizedDescription)"
        }
    }
}
