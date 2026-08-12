import Foundation
import LumiKernel

struct CreateAppStoreConnectScreenshotSetTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.create-screenshot-set",
        displayName: "Create screenshot set",
        description: "Create a screenshot set for a localization and display type."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "localizationID": .object(["type": .string("string"), "description": .string("The appStoreVersionLocalization id.")]),
                "displayType": .object(["type": .string("string"), "description": .string("Screenshot display type, e.g. APP_DESKTOP, APP_IPHONE_67.")])
            ]),
            "required": .array([.string("localizationID"), .string("displayType")])
        ])
    }

    func riskLevel(arguments: [String : LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .high
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let localizationID = arguments["localizationID"]?.stringValue, !localizationID.isEmpty else {
            return "Missing or empty localizationID."
        }
        guard let displayType = arguments["displayType"]?.stringValue, !displayType.isEmpty else {
            return "Missing or empty displayType."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let set = try await client.createScreenshotSet(localizationID: localizationID, displayType: displayType)
            return "Screenshot set created: id=\(set.id) displayType=\(set.screenshotDisplayType)"
        } catch {
            return "Failed to create screenshot set: \(error.localizedDescription)"
        }
    }
}
