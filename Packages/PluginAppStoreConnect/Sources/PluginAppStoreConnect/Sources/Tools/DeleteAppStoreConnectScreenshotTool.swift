import Foundation
import KernelCore
import KitAgentTool

public struct DeleteAppStoreConnectScreenshotTool: SuperAgentTool {
    public let name = "app_store_connect_delete_screenshot"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("Delete a screenshot from an App Store screenshot set.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("Delete Screenshot")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "screenshotID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The appScreenshot id to delete (see id field from list-screenshots)."))
                ])
            ]),
            "required": .array([.string("screenshotID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let screenshotID = arguments["screenshotID"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !screenshotID.isEmpty else {
            return "Missing or empty screenshotID."
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            try await client.deleteScreenshot(id: screenshotID)
            return "Screenshot id=\(screenshotID) deleted."
        } catch {
            return "Failed to delete screenshot: \(error.localizedDescription)"
        }
    }
}
