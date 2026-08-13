import Foundation
import KernelLumi

struct ListAppStoreConnectCiWorkflowsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-ci-workflows",
        displayName: "List Xcode Cloud workflows",
        description: "List workflows under a Xcode Cloud product."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "productID": .object([
                    "type": .string("string"),
                    "description": .string("The ciProduct id.")
                ])
            ]),
            "required": .array([.string("productID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        guard let productID = arguments["productID"]?.stringValue, !productID.isEmpty else {
            return "Missing or empty productID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
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
