import AgentToolKit
import Foundation
import ResumeKit

public struct ImportResumeAssetTool: SuperAgentTool {
    public let name = "resume_import_asset"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Copy a local image (profile photo and similar) into the plugin-managed assets directory of one resume."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = ResumeToolSupport.baseProperties()
        properties["sourcePath"] = ["type": "string"]
        properties["fileName"] = ["type": "string", "description": "Optional destination file name."]
        return ["type": "object", "properties": properties, "required": ["resumeId", "sourcePath"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Import resume asset"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let sourcePath = try ResumeToolSupport.required("sourcePath", arguments)
        let resumeID = try ResumeToolSupport.required("resumeId", arguments)
        let directory = try ResumeToolSupport.store.assetsDirectoryURL(
            storagePath: try await ResumeToolSupport.storagePath(),
            slug: resumeID
        )
        let asset = try ResumeAssetImporter().importImage(
            sourceURL: URL(fileURLWithPath: sourcePath),
            destinationDirectory: directory,
            preferredFileName: ResumeToolSupport.string(arguments, "fileName")
        )
        await ResumeToolSupport.notify(resumeID: resumeID)
        return "Imported resume asset. relativePath=\(asset.relativePath) size=\(asset.pixelWidth)x\(asset.pixelHeight)"
    }
}
