import Foundation
import LumiKernel

struct UpdateAppStoreConnectLocalizationTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.update-localization",
        displayName: "Update localization metadata",
        description: "Update editable fields of an App Store version localization."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "localizationID": .object(["type": .string("string"), "description": .string("The appStoreVersionLocalization id.")]),
                "promotionalText": .object(["type": .string("string")]),
                "description": .object(["type": .string("string")]),
                "keywords": .object(["type": .string("string")]),
                "whatsNew": .object(["type": .string("string")]),
                "supportURL": .object(["type": .string("string")]),
                "marketingURL": .object(["type": .string("string")])
            ]),
            "required": .array([.string("localizationID")])
        ])
    }

    func riskLevel(arguments: [String : LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .high
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let localizationID = arguments["localizationID"]?.stringValue, !localizationID.isEmpty else {
            return "Missing or empty localizationID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        let payload = AppStoreVersionLocalization(
            id: localizationID,
            locale: "en-US",
            promotionalText: arguments["promotionalText"]?.stringValue ?? "",
            description: arguments["description"]?.stringValue ?? "",
            keywords: arguments["keywords"]?.stringValue ?? "",
            whatsNew: arguments["whatsNew"]?.stringValue ?? "",
            supportURL: arguments["supportURL"]?.stringValue ?? "",
            marketingURL: arguments["marketingURL"]?.stringValue ?? ""
        )

        do {
            let updated = try await client.updateLocalization(payload)
            return "Localization updated: id=\(updated.id) locale=\(updated.locale)"
        } catch {
            return "Failed to update localization: \(error.localizedDescription)"
        }
    }
}
