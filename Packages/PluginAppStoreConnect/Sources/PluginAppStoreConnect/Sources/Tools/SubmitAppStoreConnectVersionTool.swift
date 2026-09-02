import Foundation
import KernelCore
import KitAgentTool

public struct SubmitAppStoreConnectVersionTool: SuperAgentTool {
    public let name = "app_store_connect_submit_version"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("Submit an App Store version to App Review. The version must have an assigned build and complete metadata/screenshots.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("Submit for Review")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect appStoreVersion id to submit."))
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
            // 前置检查：必须先关联 build
            if try await client.readAssignedBuildID(versionID: versionID) == nil {
                return "Cannot submit: no build is assigned to version id=\(versionID). Use assign-build first."
            }
            if try await client.readSubmissionID(versionID: versionID) != nil {
                return "Cannot submit: version id=\(versionID) already has a pending submission."
            }
            let submissionID = try await client.submitForReview(versionID: versionID)
            return "Version id=\(versionID) submitted for review. submission id=\(submissionID)"
        } catch {
            return "Failed to submit version: \(error.localizedDescription)"
        }
    }
}
