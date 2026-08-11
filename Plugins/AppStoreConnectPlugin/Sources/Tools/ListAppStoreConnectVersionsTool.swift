import Foundation
import LumiKernel

struct ListAppStoreConnectVersionsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-versions",
        displayName: AppStoreConnectLocalization.string("List App Store versions"),
        description: AppStoreConnectLocalization.string("List App Store Connect versions for a given app ID. Each line includes the appStoreVersion id, which is required by list-localizations, create-localization and read-version.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "appID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect app identifier (see id field from list-apps)."))
                ])
            ]),
            "required": .array([.string("appID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
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
