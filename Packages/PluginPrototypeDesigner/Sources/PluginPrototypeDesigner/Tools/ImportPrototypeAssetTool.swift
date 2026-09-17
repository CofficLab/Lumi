import Foundation
import KitAgentTool
import KitPrototype

/// 导入本地图片到原型项目的共享素材目录。
public struct ImportPrototypeAssetTool: SuperAgentTool {
    public let name = "prototype_import_asset"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Copy a local image into the prototype project's shared assets directory. Reference it from any screen's HTML with the returned relativePath."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PrototypeToolSupport.baseProperties()
        properties["sourcePath"] = ["type": "string", "description": "Absolute path of the local image file."]
        properties["fileName"] = ["type": "string", "description": "Optional destination file name."]
        return ["type": "object", "properties": properties, "required": ["projectId", "sourcePath"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Import prototype asset", zh: "导入原型素材")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let projectID = try PrototypeToolSupport.required("projectId", arguments)
        let sourcePath = try PrototypeToolSupport.required("sourcePath", arguments)
        let storagePath = try await PrototypeToolSupport.storagePath()
        let directory = try PrototypeToolSupport.store.assetsDirectoryURL(
            storagePath: storagePath,
            projectSlug: projectID
        )
        let asset = try PrototypeAssetImporter().importImage(
            sourceURL: URL(fileURLWithPath: (sourcePath as NSString).expandingTildeInPath),
            destinationDirectory: directory,
            preferredFileName: PrototypeToolSupport.string(arguments, "fileName")
        )
        await PrototypeToolSupport.notify(projectID: projectID)
        return """
        Imported asset into the shared project assets directory.
        relativePath=\(asset.relativePath) size=\(asset.pixelWidth)x\(asset.pixelHeight)
        Use it in any screen's HTML as src="\(asset.relativePath)".
        """
    }
}
