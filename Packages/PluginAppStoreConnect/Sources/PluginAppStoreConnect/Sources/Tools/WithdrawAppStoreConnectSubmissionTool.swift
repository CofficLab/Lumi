import Foundation
import KernelCore
import KitAgentTool

public struct WithdrawAppStoreConnectSubmissionTool: SuperAgentTool {
    public let name = "app_store_connect_withdraw_submission"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("Withdraw a pending App Review submission for an App Store version. Only possible while the version is waiting for review.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("Withdraw Submission")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect appStoreVersion id whose submission should be withdrawn."))
                ])
            ]),
            "required": .array([.string("versionID")])
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
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
