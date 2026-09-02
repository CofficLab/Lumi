import Foundation
import KernelCore
import KitAgentTool

public struct ListAppStoreConnectVersionsTool: SuperAgentTool {
    public let name = "app_store_connect_list_versions"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("List App Store Connect versions for a given app ID. Each line includes the appStoreVersion id, which is required by list-localizations, create-localization and read-version.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("List App Store versions")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "appID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect app identifier (see id field from list-apps)."))
                ])
            ]),
            "required": .array([.string("appID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let appID = arguments["appID"]?.stringValue, !appID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Missing or empty appID. Pass a valid App Store Connect app identifier."
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            let versions = try await client.listVersions(appID: appID)
            if versions.isEmpty {
                return "No App Store versions were found for this app."
            }

            let header = "App Store versions for app id=\(appID):"
            let lines = versions.map { version in
                let created = version.createdDate?.description ?? "unknown date"
                return "- \(version.versionString) [\(version.platform)] id=\(version.id) state=\(version.appStoreState) created=\(created)"
            }
            let footer = "Use the id field as versionID for list-localizations / create-localization / read-version."
            return ([header] + lines + [footer]).joined(separator: "\n")
        } catch {
            return "Failed to list versions: \(error.localizedDescription)"
        }
    }
}
