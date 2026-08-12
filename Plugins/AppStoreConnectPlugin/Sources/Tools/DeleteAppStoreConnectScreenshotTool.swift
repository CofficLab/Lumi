import Foundation
import LumiKernel

struct DeleteAppStoreConnectScreenshotTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.delete-screenshot",
        displayName: AppStoreConnectLocalization.string("Delete Screenshot"),
        description: AppStoreConnectLocalization.string("Delete a screenshot from an App Store screenshot set.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "screenshotID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The appScreenshot id to delete (see id field from list-screenshots)."))
                ])
            ]),
            "required": .array([.string("screenshotID")])
        ])
    }

    func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .high
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let screenshotID = arguments["screenshotID"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !screenshotID.isEmpty else {
            return "Missing or empty screenshotID."
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            try await client.deleteScreenshot(id: screenshotID)
            return "Screenshot id=\(screenshotID) deleted."
        } catch {
            return "Failed to delete screenshot: \(error.localizedDescription)"
        }
    }
}
