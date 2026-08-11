import Foundation
import LumiKernel

struct ListAppStoreConnectCiBuildRunsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-ci-build-runs",
        displayName: "List Xcode Cloud build runs",
        description: "List build runs for a Xcode Cloud workflow."
    )

    var inputSchema: LumiJSONValue {
        .object([
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
        ])
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
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
