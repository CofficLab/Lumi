import Foundation
import KernelCore
import KitAgentTool

public struct CreateAppStoreConnectScreenshotSetTool: SuperAgentTool {
    public let name = "app_store_connect_create_screenshot_set"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Create a screenshot set for a localization and display type."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Create screenshot set"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "localizationID": .object(["type": .string("string"), "description": .string("The appStoreVersionLocalization id.")]),
                "displayType": .object(["type": .string("string"), "description": .string("Screenshot display type, e.g. APP_DESKTOP, APP_IPHONE_67.")])
            ]),
            "required": .array([.string("localizationID"), .string("displayType")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let localizationID = arguments["localizationID"]?.stringValue, !localizationID.isEmpty else {
            return "Missing or empty localizationID."
        }
        guard let displayType = arguments["displayType"]?.stringValue, !displayType.isEmpty else {
            return "Missing or empty displayType."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let set = try await client.createScreenshotSet(localizationID: localizationID, displayType: displayType)
            return "Screenshot set created: id=\(set.id) displayType=\(set.screenshotDisplayType)"
        } catch {
            return "Failed to create screenshot set: \(error.localizedDescription)"
        }
    }
}
