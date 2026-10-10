import Foundation
import KernelCore
import KitAgentTool

public struct ReadAppStoreConnectVersionTool: SuperAgentTool {
    public let name = "app_store_connect_read_version"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("Read detail of a single App Store version, including its appStoreVersion id required by list-localizations and create-localization.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("Read App Store version")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect appStoreVersion id (see id field from list-versions)."))
                ])
            ]),
            "required": .array([.string("versionID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let versionID = arguments["versionID"]?.stringValue, !versionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Missing or empty versionID. Pass a valid App Store Connect appStoreVersion identifier."
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            let version = try await client.readVersion(id: versionID)
            let created = version.createdDate?.description ?? "unknown date"
            var lines = [
                "App Store version detail:",
                "- id=\(version.id)",
                "- versionString=\(version.versionString)",
                "- platform=\(version.platform)",
                "- appStoreState=\(version.appStoreState)",
                "- appVersionState=\(version.appVersionState)",
                "- created=\(created)",
            ]
            if let copyright = version.copyright {
                lines.append("- copyright=\(copyright)")
            } else {
                lines.append("- copyright=(not set)")
            }
            if let releaseType = version.releaseType {
                lines.append("- releaseType=\(releaseType)")
            }
            if let downloadable = version.downloadable {
                lines.append("- downloadable=\(downloadable)")
            }
            lines.append("Use id as versionID for list-localizations / create-localization.")
            return lines.joined(separator: "\n")
        } catch {
            return "Failed to read version: \(error.localizedDescription)"
        }
    }
}
