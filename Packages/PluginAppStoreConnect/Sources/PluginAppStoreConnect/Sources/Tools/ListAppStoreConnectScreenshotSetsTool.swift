import Foundation
import KernelCore
import KitAgentTool

public struct ListAppStoreConnectScreenshotSetsTool: SuperAgentTool {
    public let name = "app_store_connect_list_screenshot_sets"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List screenshot sets for a localization."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "List screenshot sets"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "localizationID": .object([
                    "type": .string("string"),
                    "description": .string("The appStoreVersionLocalization id.")
                ])
            ]),
            "required": .array([.string("localizationID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let localizationID = arguments["localizationID"]?.stringValue, !localizationID.isEmpty else {
            return "Missing or empty localizationID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
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
