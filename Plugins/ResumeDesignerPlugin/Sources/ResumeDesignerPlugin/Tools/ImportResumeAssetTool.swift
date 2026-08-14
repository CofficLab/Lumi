import Foundation
import KernelLumi
import ResumeKit

public struct ImportResumeAssetTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "resume_import_asset",
        displayName: "Import resume asset",
        description: "Copy a local image (profile photo and similar) into the plugin-managed assets directory of one resume."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = ResumeToolSupport.baseProperties()
        properties["sourcePath"] = ["type": "string"]
        properties["fileName"] = ["type": "string", "description": "Optional destination file name."]
        return ["type": "object", "properties": .object(properties), "required": ["resumeId", "sourcePath"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let sourcePath = try ResumeToolSupport.required("sourcePath", arguments)
        guard ResumeDocumentStore.isPathAllowed(sourcePath, allowedDirectories: kernel.allowedDirectories) else {
            throw ResumeStoreError.pathNotAllowed(sourcePath)
        }
        let scope = try await ResumeToolSupport.resolveScope(arguments, kernel: kernel)
        let resumeID = try ResumeToolSupport.required("resumeId", arguments)
        let directory = try ResumeToolSupport.store.assetsDirectoryURL(
            storagePath: try await ResumeToolSupport.storagePath(for: scope),
            slug: resumeID
        )
        let asset = try ResumeAssetImporter().importImage(
            sourceURL: URL(fileURLWithPath: sourcePath),
            destinationDirectory: directory,
            preferredFileName: arguments.string("fileName")
        )
        await ResumeToolSupport.notify(scope: scope, resumeID: resumeID)
        return "Imported resume asset (scope=\(scope.rawValue)). relativePath=\(asset.relativePath) size=\(asset.pixelWidth)x\(asset.pixelHeight)"
    }
}
