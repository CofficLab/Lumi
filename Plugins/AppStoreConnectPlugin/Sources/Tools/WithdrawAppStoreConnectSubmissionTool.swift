import Foundation
import LumiKernel

struct WithdrawAppStoreConnectSubmissionTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.withdraw-submission",
        displayName: AppStoreConnectLocalization.string("Withdraw Submission"),
        description: AppStoreConnectLocalization.string("Withdraw a pending App Review submission for an App Store version. Only possible while the version is waiting for review.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect appStoreVersion id whose submission should be withdrawn."))
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

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            guard let submissionID = try await client.readSubmissionID(versionID: versionID) else {
                return "No pending submission found for version id=\(versionID)."
            }
            try await client.withdrawSubmission(submissionID: submissionID)
            return "Submission id=\(submissionID) for version id=\(versionID) withdrawn."
        } catch {
            return "Failed to withdraw submission: \(error.localizedDescription)"
        }
    }
}
