import Foundation
import LumiKernel

struct AssignAppStoreConnectBuildTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.assign-build",
        displayName: AppStoreConnectLocalization.string("Assign Build"),
        description: AppStoreConnectLocalization.string("Assign a build to an App Store version. Required before submitting the version for review. Optionally declare export compliance (usesNonExemptEncryption) at the same time.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect appStoreVersion id."))
                ]),
                "buildID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The build id to assign (see id field from list-builds)."))
                ]),
                "usesNonExemptEncryption": .object([
                    "type": .string("boolean"),
                    "description": .string("Optional export compliance declaration for the build.")
                ])
            ]),
            "required": .array([.string("versionID"), .string("buildID")])
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
        guard let buildID = arguments["buildID"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !buildID.isEmpty else {
            return "Missing or empty buildID."
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            if let usesNonExempt = AppStoreConnectToolSupport.parseBool(arguments["usesNonExemptEncryption"]) {
                try await client.updateBuildEncryption(buildID: buildID, usesNonExemptEncryption: usesNonExempt)
            }
            try await client.assignBuild(versionID: versionID, buildID: buildID)
            return "Build id=\(buildID) assigned to version id=\(versionID)."
        } catch {
            return "Failed to assign build: \(error.localizedDescription)"
        }
    }
}
