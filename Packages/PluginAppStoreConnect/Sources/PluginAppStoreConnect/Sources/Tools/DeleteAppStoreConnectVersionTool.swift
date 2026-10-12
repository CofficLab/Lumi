import Foundation
import KernelCore
import KitAgentTool

public struct DeleteAppStoreConnectVersionTool: SuperAgentTool {
    public let name = "app_store_connect_delete_version"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("Delete an App Store version that is associated with an app, for example a draft that blocks creating a new version.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("Delete Version")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The appStoreVersion id to delete (see id field from list-versions)."))
                ])
            ]),
            "required": .array([.string("versionID")])
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

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            try await client.deleteVersion(id: versionID)
            return "App Store version id=\(versionID) deleted. If you need a different version number, create a new version with app_store_connect_create_version."
        } catch {
            return "Failed to delete version: \(error.localizedDescription)"
        }
    }
}
