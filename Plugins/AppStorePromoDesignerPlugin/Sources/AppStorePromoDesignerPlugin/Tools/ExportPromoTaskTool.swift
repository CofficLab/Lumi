import AppStorePromoKit
import Foundation
import LumiKernel

public struct ExportPromoTaskTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_export_task",
        displayName: "Export promo task",
        description: "Render every HTML image in a task to an explicitly selected external directory."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties()
        properties["displayTypes"] = ["type": "array", "items": ["type": "string"], "description": "Optional display types. Defaults to all presets for the task family."]
        properties["outputDirectory"] = ["type": "string", "description": "Required user-selected export directory. Source files remain in plugin storage."]
        properties["overwrite"] = ["type": "boolean", "description": "Allow replacing existing PNG files. Defaults to false."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "outputDirectory"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        arguments.bool("overwrite") == true ? .high : .medium
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let storagePath = try await PromoToolSupport.storagePath(for: scope)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let task = try PromoToolSupport.store.readTask(storagePath: storagePath, taskSlug: taskID)
        guard !task.images.isEmpty else { throw PromoToolSupport.ToolArgumentError.invalid("task has no images") }
        let requestedTypes = arguments.stringArray("displayTypes") ?? AppStorePromoDisplaySpec.presets(for: task.deviceFamily).map(\.displayType)
        let presets = try requestedTypes.map { type -> AppStorePromoDisplayPreset in
            guard let preset = AppStorePromoDisplaySpec.preset(for: type), preset.family == task.deviceFamily else {
                throw PromoToolSupport.ToolArgumentError.invalid("displayTypes")
            }
            return preset
        }
        let outputDirectory = URL(fileURLWithPath: (try PromoToolSupport.required("outputDirectory", arguments) as NSString).expandingTildeInPath, isDirectory: true)
        let resolvedOutput = AppStorePromoDocumentStore.resolvePath(outputDirectory.path)
        guard AppStorePromoDocumentStore.isPathAllowed(resolvedOutput, allowedDirectories: kernel.allowedDirectories) else {
            throw AppStorePromoStoreError.pathNotAllowed(resolvedOutput)
        }
        let overwrite = arguments.bool("overwrite") ?? false
        let fileManager = FileManager.default
        let outputParent = outputDirectory.deletingLastPathComponent()
        try fileManager.createDirectory(at: outputParent, withIntermediateDirectories: true)
        let stagingDirectory = outputParent.appendingPathComponent(".app-store-promo-export-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDirectory) }

        struct StagedExport {
            let stagedURL: URL
            let destinationURL: URL
            let summary: String
        }
        var stagedExports: [StagedExport] = []
        for preset in presets {
            for imageMeta in task.images.sorted(by: { $0.order < $1.order }) {
                let filename = String(format: "%02d-%@.png", imageMeta.order + 1, imageMeta.id)
                let destinationURL = outputDirectory
                    .appendingPathComponent(preset.displayType, isDirectory: true)
                    .appendingPathComponent(filename)
                if fileManager.fileExists(atPath: destinationURL.path), !overwrite {
                    throw AppStorePromoStoreError.alreadyExists(destinationURL.path)
                }

                let image = try PromoToolSupport.store.readImage(storagePath: storagePath, taskSlug: taskID, imageSlug: imageMeta.id)
                let report = try PromoToolSupport.store.lintImage(storagePath: storagePath, taskSlug: taskID, imageSlug: imageMeta.id)
                guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
                let data = try await AppStorePromoHTMLExporter.exportPNG(html: image.html, fileURL: image.htmlURL, preset: preset)
                let stagedURL = stagingDirectory.appendingPathComponent("rendered-\(stagedExports.count).png")
                try data.write(to: stagedURL, options: .atomic)
                stagedExports.append(StagedExport(
                    stagedURL: stagedURL,
                    destinationURL: destinationURL,
                    summary: "\(destinationURL.path) \(preset.width)x\(preset.height) \(data.count) bytes"
                ))
            }
        }

        let backupDirectory = stagingDirectory.appendingPathComponent("backups", isDirectory: true)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        var installedURLs: [URL] = []
        var backups: [(original: URL, backup: URL)] = []
        do {
            for (index, export) in stagedExports.enumerated() {
                try fileManager.createDirectory(at: export.destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: export.destinationURL.path) {
                    let backupURL = backupDirectory.appendingPathComponent("\(index).png")
                    try fileManager.moveItem(at: export.destinationURL, to: backupURL)
                    backups.append((export.destinationURL, backupURL))
                }
                try fileManager.moveItem(at: export.stagedURL, to: export.destinationURL)
                installedURLs.append(export.destinationURL)
            }
        } catch {
            for installedURL in installedURLs.reversed() {
                try? fileManager.removeItem(at: installedURL)
            }
            for backup in backups.reversed() {
                try? fileManager.moveItem(at: backup.backup, to: backup.original)
            }
            throw error
        }

        return (["Exported \(stagedExports.count) App Store promotional PNG files (scope=\(scope.rawValue))."] + stagedExports.map(\.summary)).joined(separator: "\n")
    }
}