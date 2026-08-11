import Foundation
import LumiKernel

struct StartAppStoreConnectCiBuildRunTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.start-ci-build-run",
        displayName: "Start Xcode Cloud build run",
        description: "Trigger a new build run for a workflow."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "workflowID": .object(["type": .string("string"), "description": .string("The ciWorkflow id.")]),
                "branch": .object(["type": .string("string"), "description": .string("Optional source branch or tag.")])
            ]),
            "required": .array([.string("workflowID")])
        ])
    }

    func riskLevel(arguments: [String : LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .high
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
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
