import Foundation
import LumiKernel

struct ListAppStoreConnectLocalizationsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-localizations",
        displayName: "List App Store localizations",
        description: "List localizations for an App Store version."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string("The App Store Connect appStoreVersion id.")
                ])
            ]),
            "required": .array([.string("versionID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let versionID = arguments["versionID"]?.stringValue, !versionID.isEmpty else {
            return "Missing or empty versionID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let localizations = try await client.listLocalizations(versionID: versionID)
            guard !localizations.isEmpty else { return "No localizations found for version id=\(versionID)." }
            let lines = localizations.map {
                "- \($0.locale) id=\($0.id) whatsNew=\($0.whatsNew.isEmpty ? "empty" : "present")"
            }
            return (["Localizations for version id=\(versionID):"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list localizations: \(error.localizedDescription)"
        }
    }
}
