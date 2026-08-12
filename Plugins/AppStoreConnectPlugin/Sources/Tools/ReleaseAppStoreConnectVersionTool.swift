import Foundation
import LumiKernel

struct ReleaseAppStoreConnectVersionTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.release-version",
        displayName: "Release App Store version",
        description: "Submit a release request for an App Store version that is ready to ship, prompting App Review or manual release depending on the version's release type."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string("The App Store Connect appStoreVersion id to release.")
                ])
            ]),
            "required": .array([.string("versionID")])
        ])
    }

    func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .high
    }

    func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard let versionID = arguments["versionID"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !versionID.isEmpty else {
            return "Missing or empty versionID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient(kernel: kernel)
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            try await client.releaseVersion(versionID: versionID)
            return "Release request submitted for version id=\(versionID)."
        } catch {
            return "Failed to release version: \(error.localizedDescription)"
        }
    }
}
