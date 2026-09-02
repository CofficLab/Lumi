import Foundation
import KernelCore
import KitAgentTool

public struct CreateAppStoreConnectLocalizationTool: SuperAgentTool {
    public let name = "app_store_connect_create_localization"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Create a new locale localization for an App Store version. All metadata fields are optional and default to empty strings."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Create App Store localization"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string("The App Store Connect appStoreVersion id.")
                ]),
                "locale": .object([
                    "type": .string("string"),
                    "description": .string("Locale code, e.g. en-US, zh-Hans.")
                ]),
                "promotionalText": .object(["type": .string("string")]),
                "description": .object(["type": .string("string")]),
                "keywords": .object(["type": .string("string")]),
                "whatsNew": .object(["type": .string("string")]),
                "supportURL": .object(["type": .string("string")]),
                "marketingURL": .object(["type": .string("string")])
            ]),
            "required": .array([.string("versionID"), .string("locale")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let versionID = arguments["versionID"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !versionID.isEmpty else {
            return "Missing or empty versionID."
        }
        guard let locale = arguments["locale"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !locale.isEmpty else {
            return "Missing or empty locale."
        }

        let attributes = AppStoreVersionLocalization.CreateAttributes(
            promotionalText: arguments["promotionalText"]?.stringValue ?? "",
            description: arguments["description"]?.stringValue ?? "",
            keywords: arguments["keywords"]?.stringValue ?? "",
            whatsNew: arguments["whatsNew"]?.stringValue ?? "",
            supportURL: arguments["supportURL"]?.stringValue ?? "",
            marketingURL: arguments["marketingURL"]?.stringValue ?? ""
        )

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let created = try await client.createLocalization(
                versionID: versionID,
                locale: locale,
                attributes: attributes
            )
            return "Localization created: id=\(created.id) locale=\(created.locale)"
        } catch {
            return "Failed to create localization: \(error.localizedDescription)"
        }
    }
}
