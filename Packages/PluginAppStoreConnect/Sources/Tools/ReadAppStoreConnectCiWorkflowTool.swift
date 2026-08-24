import Foundation
import KernelLumi

struct ReadAppStoreConnectCiWorkflowTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.read-ci-workflow",
        displayName: "Read Xcode Cloud workflow",
        description: "Read a single workflow detail from Xcode Cloud."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "workflowID": .object([
                    "type": .string("string"),
                    "description": .string("The ciWorkflow id.")
                ])
            ]),
            "required": .array([.string("workflowID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        guard let workflowID = arguments["workflowID"]?.stringValue, !workflowID.isEmpty else {
            return "Missing or empty workflowID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
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
