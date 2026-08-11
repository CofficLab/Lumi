import Foundation
import LumiKernel

struct UpdateAppStoreConnectLocalizationTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.update-localization",
        displayName: "Update localization metadata",
        description: "Update editable fields of an App Store version localization. Only the fields you provide are changed; omitted fields keep their current values. Pass an empty string for supportURL/marketingURL to clear them."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "localizationID": .object(["type": .string("string"), "description": .string("The appStoreVersionLocalization id (see id field from list-localizations).")]),
                "promotionalText": .object(["type": .string("string")]),
                "description": .object(["type": .string("string")]),
                "keywords": .object(["type": .string("string"), "description": .string("Comma-separated keywords, max 100 characters.")]),
                "whatsNew": .object(["type": .string("string")]),
                "supportURL": .object(["type": .string("string"), "description": .string("A valid URL, e.g. https://example.com/support. Empty string clears it.")]),
                "marketingURL": .object(["type": .string("string"), "description": .string("A valid URL. Empty string clears it.")])
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

        // Only the fields explicitly provided by the caller are sent in the PATCH body;
        // unset fields keep their current values on App Store Connect.
        let promotionalText = arguments["promotionalText"]?.stringValue
        let description = arguments["description"]?.stringValue
        let keywords = arguments["keywords"]?.stringValue
        let whatsNew = arguments["whatsNew"]?.stringValue
        let supportURL = arguments["supportURL"]?.stringValue
        let marketingURL = arguments["marketingURL"]?.stringValue

        guard promotionalText != nil || description != nil || keywords != nil
                || whatsNew != nil || supportURL != nil || marketingURL != nil else {
            return "Nothing to update. Provide at least one of: promotionalText, description, keywords, whatsNew, supportURL, marketingURL."
        }

        do {
            let updated = try await client.updateLocalization(
                id: localizationID,
                promotionalText: promotionalText,
                description: description,
                keywords: keywords,
                whatsNew: whatsNew,
                supportURL: supportURL,
                marketingURL: marketingURL
            )
            return "Localization updated: id=\(updated.id) locale=\(updated.locale)"
        } catch {
            return "Failed to update localization: \(error.localizedDescription)"
        }
    }
}
