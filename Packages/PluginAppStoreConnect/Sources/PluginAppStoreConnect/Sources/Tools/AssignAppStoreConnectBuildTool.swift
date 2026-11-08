import Foundation
import KernelCore
import KitAgentTool

public struct AssignAppStoreConnectBuildTool: SuperAgentTool {
    public let name = "app_store_connect_assign_build"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("Assign a build to an App Store version. Required before submitting the version for review. Optionally declare export compliance (usesNonExemptEncryption) at the same time.")
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        AppStoreConnectLocalization.string("Assign Build")
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        AppStoreConnectToolSchemaValue.object([
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
        ]).dictionaryValue
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let versionID = arguments["versionID"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !versionID.isEmpty else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Missing or empty versionID.")
        }
        guard let buildID = arguments["buildID"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !buildID.isEmpty else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Missing or empty buildID.")
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { throw ToolExecutionError.executionFailed(toolName: name, reason: errorMessage ?? "Failed to initialize App Store Connect client.") }

        do {
            // 关联是主操作，先做。出口合规声明只是附带的可选写入，
            // 不能让它的失败把 build 留成未关联。
            try await client.assignBuild(versionID: versionID, buildID: buildID)
        } catch {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Failed to assign build: \(error.localizedDescription)")
        }

        var content = "Build id=\(buildID) assigned to version id=\(versionID)."
        if let usesNonExempt = AppStoreConnectToolSupport.parseBool(arguments["usesNonExemptEncryption"]) {
            do {
                try await client.updateBuildEncryption(buildID: buildID, usesNonExemptEncryption: usesNonExempt)
            } catch {
                // 声明没写成功不能推翻已完成的关联：把它降级为结果里的提示。
                content += " Export compliance was not updated: \(error.localizedDescription)"
            }
        }
        return content
    }
}
