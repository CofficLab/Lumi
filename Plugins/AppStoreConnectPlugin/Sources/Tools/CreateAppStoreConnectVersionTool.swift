import Foundation
import LumiKernel

struct CreateAppStoreConnectVersionTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.create-version",
        displayName: AppStoreConnectLocalization.string("New Version"),
        description: AppStoreConnectLocalization.string("Create a new App Store version for the selected app.")
    )

    var inputSchema: LumiJSONValue {
        .object([
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
        ])
    }

    func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .high
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
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

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
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
