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
            // 前置检查 1：必须先关联 build
            if try await client.readAssignedBuildID(versionID: versionID) == nil {
                return "Cannot submit: no build is assigned to version id=\(versionID). Use assign-build first."
            }
            // 前置检查 2：不能重复提交
            if try await client.readSubmissionID(versionID: versionID) != nil {
                return "Cannot submit: version id=\(versionID) already has a pending submission."
            }

            // 前置检查 3：收集潜在问题并给出详细提示
            var warnings: [String] = []

            // 3a. 版本属性检查
            let version = try await client.readVersion(id: versionID)
            if version.copyright == nil || version.copyright?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                warnings.append("copyright is not set. Use update-version to set it if required.")
            }

            // 3b. 年龄分级检查（声明为 app 级资源，经 appInfo 读取）
            let ageRating = try await client.readAgeRatingDeclaration(versionID: versionID)
            if ageRating == nil {
                warnings.append(
                    "No age-rating declaration found. The ASC API cannot create one — "
                    + "complete the questionnaire once for this app via the App Store Connect website "
                    + "(App Information → Age Ratings → Set Up Age Ratings → Save), "
                    + "then use set-age-rating to update programmatically."
                )
            }

            // 3c. 本地化信息检查
            let localizations = try await client.listLocalizations(versionID: versionID)
            if localizations.isEmpty {
                warnings.append("No localizations found. Use create-localization to add at least one locale with description.")
            } else {
                for loc in localizations {
                    if loc.description.trimmingCharacters(in: .whitespaces).isEmpty {
                        warnings.append("Localization '\(loc.locale)' has an empty description. Update it before submitting.")
                    }
                }
            }

            if !warnings.isEmpty {
                let warningText = warnings.map { "- \($0)" }.joined(separator: "\n")
                return """
                Cannot submit: version id=\(versionID) may be missing required configuration.
                Warnings:
                \(warningText)
                Fix the issues above and try again.
                """
            }

            let submissionID = try await client.submitForReview(versionID: versionID)
            return "Version id=\(versionID) submitted for review. submission id=\(submissionID)"
        } catch {
            return "Failed to submit version: \(error.localizedDescription)"
        }
    }
}
