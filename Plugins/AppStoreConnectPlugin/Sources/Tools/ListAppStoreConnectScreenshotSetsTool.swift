import Foundation
import LumiKernel

struct ListAppStoreConnectScreenshotSetsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-screenshot-sets",
        displayName: "List screenshot sets",
        description: "List screenshot sets for a localization."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "localizationID": .object([
                    "type": .string("string"),
                    "description": .string("The appStoreVersionLocalization id.")
                ])
            ]),
            "required": .array([.string("localizationID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let localizationID = arguments["localizationID"]?.stringValue, !localizationID.isEmpty else {
            return "Missing or empty localizationID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let payload = try await client.loadScreenshotSets(localizationID: localizationID)
            guard !payload.sets.isEmpty else { return "No screenshot sets found for localization id=\(localizationID)." }
            let lines = payload.sets.map { set in
                let count = payload.screenshotsBySetID[set.id]?.count ?? set.screenshotIDs.count
                return "- \(set.screenshotDisplayType) setID=\(set.id) screenshots=\(count)"
            }
            return (["Screenshot sets for localization id=\(localizationID):"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list screenshot sets: \(error.localizedDescription)"
        }
    }
}
