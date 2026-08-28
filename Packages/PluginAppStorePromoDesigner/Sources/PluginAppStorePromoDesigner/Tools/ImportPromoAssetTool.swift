import KitAgentTool
import KitAppStorePromo
import Foundation

/// 将本地图片复制到促销图插件管理的资源目录。
public struct ImportPromoAssetTool: SuperAgentTool {
    public let name = "app_store_promo_import_asset"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Copy a local image into the plugin-managed assets directory for one promotional image."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["sourcePath"] = ["type": "string"]
        properties["fileName"] = ["type": "string", "description": "Optional destination file name."]
        return ["type": "object", "properties": properties, "required": ["taskId", "imageId", "sourcePath"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "Import promo asset", zh: "导入促销图资源")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let sourcePath = try PromoToolSupport.required("sourcePath", arguments)
        let scope = try await PromoToolSupport.resolveScope(arguments)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        let directory = try PromoToolSupport.store.assetsDirectoryURL(
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID,
            imageSlug: imageID
        )
        let asset = try AppStorePromoAssetImporter().importImage(
            sourceURL: URL(fileURLWithPath: sourcePath),
            destinationDirectory: directory,
            preferredFileName: PromoToolSupport.string(arguments, "fileName")
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Imported promotional asset (scope=\(scope.rawValue)). relativePath=\(asset.relativePath) size=\(asset.pixelWidth)x\(asset.pixelHeight)"
    }
}
