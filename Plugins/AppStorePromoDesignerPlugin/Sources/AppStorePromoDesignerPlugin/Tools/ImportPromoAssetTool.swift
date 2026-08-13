import AppStorePromoKit
import Foundation
import KernelLumi

public struct ImportPromoAssetTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_import_asset",
        displayName: "Import promo asset",
        description: "Copy a local image into the plugin-managed assets directory for one promotional image."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["sourcePath"] = ["type": "string"]
        properties["fileName"] = ["type": "string", "description": "Optional destination file name."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId", "sourcePath"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let sourcePath = try PromoToolSupport.required("sourcePath", arguments)
        guard AppStorePromoDocumentStore.isPathAllowed(sourcePath, allowedDirectories: kernel.allowedDirectories) else {
            throw AppStorePromoStoreError.pathNotAllowed(sourcePath)
        }
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
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
            preferredFileName: arguments.string("fileName")
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Imported promotional asset (scope=\(scope.rawValue)). relativePath=\(asset.relativePath) size=\(asset.pixelWidth)x\(asset.pixelHeight)"
    }
}