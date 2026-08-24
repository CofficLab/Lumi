import Foundation
import KernelLumi

struct ReadAppStoreConnectVersionTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.read-version",
        displayName: AppStoreConnectLocalization.string("Read App Store version"),
        description: AppStoreConnectLocalization.string("Read detail of a single App Store version, including its appStoreVersion id required by list-localizations and create-localization.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect appStoreVersion id (see id field from list-versions)."))
                ])
            ]),
            "required": .array([.string("versionID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        guard let versionID = arguments["versionID"]?.stringValue, !versionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Missing or empty versionID. Pass a valid App Store Connect appStoreVersion identifier."
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            let version = try await client.readVersion(id: versionID)
            let created = version.createdDate?.description ?? "unknown date"
            return """
            App Store version detail:
            - id=\(version.id)
            - versionString=\(version.versionString)
            - platform=\(version.platform)
            - appStoreState=\(version.appStoreState)
            - appVersionState=\(version.appVersionState)
            - created=\(created)
            Use id as versionID for list-localizations / create-localization.
            """
        } catch {
            return "Failed to read version: \(error.localizedDescription)"
        }
    }
}
