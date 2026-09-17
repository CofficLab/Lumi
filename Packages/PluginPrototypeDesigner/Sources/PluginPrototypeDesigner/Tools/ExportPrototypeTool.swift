import AppKit
import Foundation
import KitAgentTool
import KitPrototype

/// 把原型项目的每一屏渲染成 PNG 导出到指定目录。
public struct ExportPrototypeTool: SuperAgentTool {
    public let name = "prototype_export"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Render every screen of a prototype project to PNG files in an explicitly selected external directory. Files are named by screen order and slug."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PrototypeToolSupport.baseProperties()
        properties["outputDirectory"] = ["type": "string", "description": "Required user-selected export directory. Source files remain in project storage."]
        properties["overwrite"] = ["type": "boolean", "description": "Allow replacing existing PNG files. Defaults to false."]
        return ["type": "object", "properties": properties, "required": ["projectId", "outputDirectory"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Export prototype", zh: "导出原型")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        PrototypeToolSupport.bool(arguments, "overwrite") ? .high : .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let storagePath = try await PrototypeToolSupport.storagePath()
        let projectID = try PrototypeToolSupport.required("projectId", arguments)
        let project = try PrototypeToolSupport.store.readProject(
            storagePath: storagePath,
            projectSlug: projectID
        )
        guard !project.screens.isEmpty else {
            throw PrototypeToolSupport.ToolArgumentError.invalid("project has no screens")
        }

        let rawOutput = try PrototypeToolSupport.required("outputDirectory", arguments)
        let outputDirectory = URL(
            fileURLWithPath: (rawOutput as NSString).expandingTildeInPath,
            isDirectory: true
        )
        let overwrite = PrototypeToolSupport.bool(arguments, "overwrite")
        let fileManager = FileManager.default
        let device = project.device

        // 先在暂存目录渲染，全部成功后再原子安装，避免半成品导出。
        let outputParent = outputDirectory.deletingLastPathComponent()
        try fileManager.createDirectory(at: outputParent, withIntermediateDirectories: true)
        let stagingDirectory = outputParent.appendingPathComponent(
            ".prototype-export-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDirectory) }

        struct StagedExport {
            let stagedURL: URL
            let destinationURL: URL
            let summary: String
        }
        var staged: [StagedExport] = []

        for screen in project.sortedScreens {
            let resolved = try PrototypeToolSupport.store.readScreen(
                storagePath: storagePath,
                projectSlug: projectID,
                screenSlug: screen.id
            )
            let report = try PrototypeToolSupport.store.lintScreen(
                storagePath: storagePath,
                projectSlug: projectID,
                screenSlug: screen.id
            )
            guard report.isValid else { throw PrototypeStoreError.invalidHTML(report.errors) }

            let filename = String(format: "%02d-%@.png", screen.order + 1, screen.id)
            let destinationURL = outputDirectory.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: destinationURL.path), !overwrite {
                throw PrototypeStoreError.alreadyExists(destinationURL.path)
            }

            let data = try await PrototypeHTMLExporter.exportPNG(
                html: resolved.html,
                fileURL: resolved.htmlURL,
                device: device
            )
            let stagedURL = stagingDirectory.appendingPathComponent("rendered-\(staged.count).png")
            try data.write(to: stagedURL, options: .atomic)
            staged.append(StagedExport(
                stagedURL: stagedURL,
                destinationURL: destinationURL,
                summary: "\(destinationURL.path) \(device.pixelWidth)x\(device.pixelHeight) \(data.count) bytes"
            ))
        }

        var installedURLs: [URL] = []
        var backups: [(original: URL, backup: URL)] = []
        let backupDirectory = stagingDirectory.appendingPathComponent("backups", isDirectory: true)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        do {
            for (index, export) in staged.enumerated() {
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

        await PrototypeToolSupport.notify(projectID: projectID)
        return (["Exported \(staged.count) prototype screen PNG files."] + staged.map(\.summary))
            .joined(separator: "\n")
    }
}
