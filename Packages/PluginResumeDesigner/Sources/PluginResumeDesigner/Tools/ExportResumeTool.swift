import KitAgentTool
import Foundation
import KitResume

public struct ExportResumeTool: SuperAgentTool {
    public let name = "resume_export"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Export one resume as vector PDF (print-ready, selectable text) and/or DPI-controlled PNG pages to an explicitly selected external directory."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = ResumeToolSupport.baseProperties()
        properties["format"] = ["type": "string", "enum": ["pdf", "png", "both"], "description": "Defaults to 'pdf'."]
        properties["dpi"] = [
            "type": "integer",
            "enum": ResumeExportResolution.allCases.map(\.rawValue),
            "description": "PNG resolution. Defaults to 300 (print quality).",
        ]
        properties["outputDirectory"] = ["type": "string", "description": "Required user-selected export directory. Source files remain in plugin storage."]
        properties["overwrite"] = ["type": "boolean", "description": "Allow replacing existing files. Defaults to false."]
        return ["type": "object", "properties": properties, "required": ["resumeId", "outputDirectory"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Export resume"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        ResumeToolSupport.bool(arguments, "overwrite", default: false) ? .high : .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let storagePath = try await ResumeToolSupport.storagePath()
        let resumeID = try ResumeToolSupport.required("resumeId", arguments)
        let resume = try ResumeToolSupport.store.readResume(storagePath: storagePath, slug: resumeID)
        let report = try ResumeToolSupport.store.lintResume(storagePath: storagePath, slug: resumeID)
        guard report.isValid else { throw ResumeStoreError.invalidHTML(report.errors) }

        let format = (ResumeToolSupport.string(arguments, "format") ?? "pdf").lowercased()
        guard ["pdf", "png", "both"].contains(format) else {
            throw ResumeToolSupport.ResumeToolArgumentError.invalid("format")
        }
        let dpiRaw = ResumeToolSupport.int(arguments, "dpi") ?? ResumeExportResolution.print.rawValue
        guard let resolution = ResumeExportResolution(rawValue: dpiRaw) else {
            throw ResumeToolSupport.ResumeToolArgumentError.invalid("dpi")
        }

        let outputDirectory = URL(
            fileURLWithPath: (try ResumeToolSupport.required("outputDirectory", arguments) as NSString).expandingTildeInPath,
            isDirectory: true
        )
        let resolvedOutput = ResumeDocumentStore.resolvePath(outputDirectory.path)

        // 渲染（矢量 PDF 为唯一源；PNG 由其栅格化）。
        // PDF 与 PNG 均返回 Sendable 的 Data，避免跨隔离域传递 PDFDocument。
        var pdfData: Data?
        if format == "pdf" || format == "both" {
            pdfData = try await ResumeHTMLExporter.exportPDF(
                html: resume.html,
                fileURL: resume.htmlURL,
                paper: resume.document.paper
            )
        }
        var pngDatas: [Data] = []
        if format == "png" || format == "both" {
            pngDatas = try await ResumeHTMLExporter.exportPNGs(
                html: resume.html,
                fileURL: resume.htmlURL,
                paper: resume.document.paper,
                dpi: resolution.rawValue
            )
        }
        let preset = ResumePaperSpec.preset(for: resume.document.paper)

        let overwrite = ResumeToolSupport.bool(arguments, "overwrite", default: false)
        let fileManager = FileManager.default
        let outputParent = URL(fileURLWithPath: resolvedOutput, isDirectory: true).deletingLastPathComponent()
        try fileManager.createDirectory(at: outputParent, withIntermediateDirectories: true)
        let stagingDirectory = outputParent.appendingPathComponent(".resume-export-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDirectory) }

        struct StagedExport {
            let stagedURL: URL
            let destinationURL: URL
            let summary: String
        }
        var stagedExports: [StagedExport] = []

        if let pdfData {
            let destinationURL = URL(fileURLWithPath: resolvedOutput, isDirectory: true)
                .appendingPathComponent("\(resume.document.id).pdf")
            if fileManager.fileExists(atPath: destinationURL.path), !overwrite {
                throw ResumeStoreError.alreadyExists(destinationURL.path)
            }
            let stagedURL = stagingDirectory.appendingPathComponent("resume.pdf")
            try pdfData.write(to: stagedURL, options: .atomic)
            stagedExports.append(StagedExport(
                stagedURL: stagedURL,
                destinationURL: destinationURL,
                summary: "\(destinationURL.path) vector PDF \(Int(preset.pdfWidth))x\(Int(preset.pdfHeight))pt \(pdfData.count) bytes"
            ))
        }
        for (pageIndex, data) in pngDatas.enumerated() {
            let filename = String(format: "%@-p%02d.png", resume.document.id, pageIndex + 1)
            let destinationURL = URL(fileURLWithPath: resolvedOutput, isDirectory: true)
                .appendingPathComponent(filename)
            if fileManager.fileExists(atPath: destinationURL.path), !overwrite {
                throw ResumeStoreError.alreadyExists(destinationURL.path)
            }
            let stagedURL = stagingDirectory.appendingPathComponent("rendered-\(pageIndex).png")
            try data.write(to: stagedURL, options: .atomic)
            let pixels = preset.pixelSize(dpi: resolution.rawValue)
            stagedExports.append(StagedExport(
                stagedURL: stagedURL,
                destinationURL: destinationURL,
                summary: "\(destinationURL.path) \(Int(pixels.width))x\(Int(pixels.height)) \(resolution.rawValue)dpi PNG"
            ))
        }
        guard !stagedExports.isEmpty else { throw ResumeExportError.pdfCreationFailed }

        // 事务式安装：staging → 备份 → 落盘，失败回滚。
        let backupDirectory = stagingDirectory.appendingPathComponent("backups", isDirectory: true)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        var installedURLs: [URL] = []
        var backups: [(original: URL, backup: URL)] = []
        do {
            for (index, export) in stagedExports.enumerated() {
                try fileManager.createDirectory(at: export.destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: export.destinationURL.path) {
                    let backupURL = backupDirectory.appendingPathComponent("\(index)-\(export.destinationURL.lastPathComponent)")
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

        await ResumeToolSupport.notify(resumeID: resumeID)
        return (["Exported \(stagedExports.count) file(s)."] + stagedExports.map(\.summary)).joined(separator: "\n")
    }
}
