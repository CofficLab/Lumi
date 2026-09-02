import Foundation
import KernelCore
import KitAgentTool

public struct CreateAppStoreConnectVersionTool: SuperAgentTool {
    public let name = "app_store_connect_create_version"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("Create a new App Store version for the selected app.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("New Version")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "appID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect app identifier (see id field from list-apps)."))
                ]),
                "versionString": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("Version Number"))
                ]),
                "platform": .object([
                    "type": .string("string"),
                    "description": .string("Platform: IOS, MAC_OS, TV_OS, or VISION_OS.")
                ]),
                "releaseType": .object([
                    "type": .string("string"),
                    "description": .string("Optional release type: AFTER_APPROVAL (default) or MANUAL.")
                ])
            ]),
            "required": .array([.string("appID"), .string("versionString"), .string("platform")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let appID = arguments["appID"]?.stringValue, !appID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Missing or empty appID."
        }
        guard let versionString = arguments["versionString"]?.stringValue,
              !versionString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Missing or empty versionString."
        }
        guard let platform = arguments["platform"]?.stringValue,
              !platform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Missing or empty platform."
        }

        let releaseType = arguments["releaseType"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedReleaseType = (releaseType?.isEmpty == false) ? releaseType! : "AFTER_APPROVAL"

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            let existingVersions = try await client.listVersions(appID: appID)
            let validated = try AppStoreVersion.validateCreate(
                versionString: versionString,
                platform: platform,
                versions: existingVersions
            )
            let created = try await client.createVersion(
                appID: appID,
                versionString: validated.versionString,
                platform: validated.platform,
                releaseType: resolvedReleaseType
            )
            return "App Store version created: id=\(created.id) version=\(created.versionString) platform=\(created.platform) state=\(created.appStoreState)"
        } catch {
            return "Failed to create version: \(error.localizedDescription)"
        }
    }
}
