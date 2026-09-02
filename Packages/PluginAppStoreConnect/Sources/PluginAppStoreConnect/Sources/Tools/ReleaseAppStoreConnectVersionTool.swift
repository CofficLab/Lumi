import Foundation
import KernelCore
import KitAgentTool

public struct ReleaseAppStoreConnectVersionTool: SuperAgentTool {
    public let name = "app_store_connect_release_version"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Submit a release request for an App Store version that is ready to ship, prompting App Review or manual release depending on the version's release type."
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Release App Store version"
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string("The App Store Connect appStoreVersion id to release.")
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
            try await client.releaseVersion(versionID: versionID)
            return "Release request submitted for version id=\(versionID)."
        } catch {
            return "Failed to release version: \(error.localizedDescription)"
        }
    }
}
