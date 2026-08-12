import Foundation
import LumiKernel

struct ListAppStoreConnectBuildsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-builds",
        displayName: AppStoreConnectLocalization.string("List Builds"),
        description: AppStoreConnectLocalization.string("List builds uploaded to App Store Connect for an app, including processing state and export compliance declaration.")
    )

    var inputSchema: LumiJSONValue {
        .object([
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
        ])
    }

    func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
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
