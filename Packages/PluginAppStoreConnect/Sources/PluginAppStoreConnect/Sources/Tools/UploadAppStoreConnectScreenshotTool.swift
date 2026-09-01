import Foundation
import KernelCore
import KitAgentTool

public struct UploadAppStoreConnectScreenshotTool: SuperAgentTool {
    public let name = "app_store_connect_upload_screenshot"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("Upload a local screenshot image file (PNG/JPEG) into an App Store screenshot set.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("Upload Screenshot")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "screenshotSetID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The appScreenshotSet id (see id field from list-screenshot-sets)."))
                ]),
                "filePath": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("Absolute path to the local screenshot image file."))
                ])
            ]),
            "required": .array([.string("screenshotSetID"), .string("filePath")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let setID = arguments["screenshotSetID"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !setID.isEmpty else {
            return "Missing or empty screenshotSetID."
        }
        guard let filePath = arguments["filePath"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !filePath.isEmpty else {
            return "Missing or empty filePath."
        }

        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return "File not found: \(filePath)"
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            let screenshotID = try await client.uploadScreenshot(setID: setID, fileURL: fileURL)
            return "Screenshot uploaded: id=\(screenshotID) file=\(fileURL.lastPathComponent) set=\(setID)"
        } catch {
            return "Failed to upload screenshot: \(error.localizedDescription)"
        }
    }
}
