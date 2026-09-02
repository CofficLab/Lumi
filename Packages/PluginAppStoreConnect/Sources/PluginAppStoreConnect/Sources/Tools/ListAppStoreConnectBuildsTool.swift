import Foundation
import KernelCore
import KitAgentTool

public struct ListAppStoreConnectBuildsTool: SuperAgentTool {
    public let name = "app_store_connect_list_builds"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("List builds uploaded to App Store Connect for an app, including processing state and export compliance declaration.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("List Builds")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "appID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect app identifier (see id field from list-apps)."))
                ]),
                "platform": .object([
                    "type": .string("string"),
                    "description": .string("Optional platform filter: IOS, MAC_OS, TV_OS, or VISION_OS.")
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
            return "Missing or empty appID."
        }
        let platform = arguments["platform"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            let builds = try await client.listBuilds(
                appID: appID,
                platform: (platform?.isEmpty == false) ? platform : nil
            )
            guard !builds.isEmpty else { return "No builds found for app id=\(appID)." }
            let lines = builds.map { build in
                var line = "- id=\(build.id) version=\(build.displayLabel) state=\(build.processingState)"
                if build.expired { line += " expired=true" }
                if let encryption = build.usesNonExemptEncryption {
                    line += " usesNonExemptEncryption=\(encryption)"
                } else {
                    line += " usesNonExemptEncryption=undeclared"
                }
                return line
            }
            return (["Builds for app id=\(appID):"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list builds: \(error.localizedDescription)"
        }
    }
}
