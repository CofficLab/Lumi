import Foundation
import KernelCore
import KitAgentTool

public struct ListAppStoreConnectScreenshotsTool: SuperAgentTool {
    public let name = "app_store_connect_list_screenshots"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List screenshots for a screenshot set."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "List screenshots"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "screenshotSetID": .object([
                    "type": .string("string"),
                    "description": .string("The appScreenshotSet id.")
                ])
            ]),
            "required": .array([.string("screenshotSetID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let screenshotSetID = arguments["screenshotSetID"]?.stringValue, !screenshotSetID.isEmpty else {
            return "Missing or empty screenshotSetID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let screenshots = try await client.listScreenshots(screenshotSetID: screenshotSetID)
            guard !screenshots.isEmpty else { return "No screenshots found for screenshot set id=\(screenshotSetID)." }
            let lines = screenshots.map { shot in
                let size = shot.fileSize.map(String.init) ?? "unknown"
                return "- \(shot.fileName.isEmpty ? "(unnamed)" : shot.fileName) id=\(shot.id) bytes=\(size)"
            }
            return (["Screenshots for set id=\(screenshotSetID):"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list screenshots: \(error.localizedDescription)"
        }
    }
}
