import Foundation
import KernelCore
import KitAgentTool

public struct UpdateAppStoreConnectVersionTool: SuperAgentTool {
    public let name = "app_store_connect_update_version"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("Update editable attributes of an App Store version such as copyright, releaseType, downloadable, or earliestReleaseDate. Only the fields you provide are changed; omitted fields keep their current values.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("Update version attributes")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect appStoreVersion id."))
                ]),
                "copyright": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("Copyright notice, e.g. '© 2024 Your Company'."))
                ]),
                "releaseType": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("Release type: AFTER_APPROVAL or MANUAL."))
                ]),
                "downloadable": .object([
                    "type": .string("boolean"),
                    "description": .string(AppStoreConnectLocalization.string("Whether the version is downloadable."))
                ]),
                "earliestReleaseDate": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("Earliest scheduled release date in ISO 8601 format (e.g. 2026-01-01T10:00:00Z). Pass an empty string to clear it."))
                ])
            ]),
            "required": .array([.string("versionID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let versionID = arguments["versionID"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !versionID.isEmpty else {
            return "Missing or empty versionID."
        }

        let copyright = arguments["copyright"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let releaseType = arguments["releaseType"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let downloadable = AppStoreConnectToolSupport.parseBool(arguments["downloadable"])
        let earliestReleaseDate = arguments["earliestReleaseDate"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)

        if copyright == nil, releaseType == nil, downloadable == nil, earliestReleaseDate == nil {
            return "No update fields provided. Pass copyright, releaseType, downloadable, or earliestReleaseDate."
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            let updated = try await client.updateVersion(
                id: versionID,
                copyright: copyright,
                releaseType: releaseType,
                downloadable: downloadable,
                earliestReleaseDate: earliestReleaseDate
            )
            var lines = [
                "Version id=\(versionID) updated.",
                "- versionString=\(updated.versionString)",
                "- appStoreState=\(updated.appStoreState)",
            ]
            if let c = updated.copyright {
                lines.append("- copyright=\(c)")
            }
            if let r = updated.releaseType {
                lines.append("- releaseType=\(r)")
            }
            if let e = updated.earliestReleaseDate {
                lines.append("- earliestReleaseDate=\(e)")
            }
            return lines.joined(separator: "\n")
        } catch {
            return "Failed to update version: \(error.localizedDescription)"
        }
    }
}
