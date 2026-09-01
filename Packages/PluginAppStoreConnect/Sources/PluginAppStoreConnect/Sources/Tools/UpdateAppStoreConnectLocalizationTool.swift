import Foundation
import KernelCore
import KitAgentTool

public struct UpdateAppStoreConnectLocalizationTool: SuperAgentTool {
    public let name = "app_store_connect_update_localization"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Update editable fields of an App Store version localization. Only the fields you provide are changed; omitted fields keep their current values. supportURL/marketingURL accept empty strings, which are mapped to JSON null and clear the field (Apple rejects '' as an invalid RFC 3986 URI). All other string fields are written verbatim — passing an empty string overwrites the field with ''. Always read-localization first, then call update-localization with the changed fields plus the verbatim values of any other field you want to preserve."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Update localization metadata"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
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
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
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
