import Foundation
import KitAgentTool

/// 把 PDF 拼版为可打印的小册子：A4 双面打印后沿中线折叠、骑马钉装订
/// 即得正确页序的小册子。
public struct BookletMakeTool: SuperAgentTool {
    public let name = "booklet_make"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Impose a PDF into a print-ready booklet PDF: two reduced portrait source pages per landscape sheet, in fold order. Print duplex, fold along the centre line and staple."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = BookletToolSupport.settingsProperties()
        properties["sourcePath"] = BookletToolSupport.pathProperty(
            "Absolute path of the source PDF file."
        )
        properties["outputPath"] = BookletToolSupport.pathProperty(
            "Absolute path of the booklet PDF to write. Parent directories are created as needed."
        )
        properties["overwrite"] = [
            "type": "boolean",
            "description": "Allow replacing an existing output file. Defaults to false.",
        ]
        return BookletToolSupport.schema(
            properties,
            required: ["sourcePath", "outputPath"]
        )
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let name = BookletToolSupport.string(arguments, "sourcePath")
            .map { URL(fileURLWithPath: $0).lastPathComponent }
        return BookletToolSupport.localized(
            BookletToolSupport.language,
            en: "Make booklet from \(name ?? "PDF")",
            zh: "制作小册子 \(name ?? "PDF")"
        )
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        BookletToolSupport.bool(arguments, "overwrite", default: false) ? .high : .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = BookletToolSupport.language
        let sourceURL = try BookletToolSupport.requiredPath("sourcePath", arguments)
        let outputURL = try BookletToolSupport.requiredPath("outputPath", arguments)
        let overwrite = BookletToolSupport.bool(arguments, "overwrite", default: false)

        do {
            let settings = try BookletToolSupport.validatedSettings(arguments)
            let info = try await PDFInspector().inspect(sourceURL)

            let fileManager = FileManager.default
            let outputExists = fileManager.fileExists(atPath: outputURL.path)
            if outputExists, !overwrite {
                throw BookletMakeError.outputExists(outputURL)
            }
            let parentDirectory = outputURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)

            // 先渲染到同目录的临时文件，成功后再替换目标：覆盖已有文件时
            // 若渲染失败，用户的旧文件必须原封不动。
            let stagingURL = parentDirectory.appendingPathComponent(
                ".booklet-\(UUID().uuidString).pdf",
                isDirectory: false
            )
            defer { try? fileManager.removeItem(at: stagingURL) }

            _ = try await BookletRenderer().render(
                sourceURL: sourceURL,
                outputURL: stagingURL,
                settings: settings
            )

            if outputExists {
                _ = try fileManager.replaceItemAt(outputURL, withItemAt: stagingURL)
            } else {
                try fileManager.moveItem(at: stagingURL, to: outputURL)
            }

            let sheets = BookletLayoutEngine.buildPhysicalSheets(
                inputPageCount: info.pageCount,
                settings: settings
            ).count

            return """
            Created booklet PDF.
            path: \(outputURL.path)
            sourcePages: \(info.pageCount) → physicalSheets: \(sheets) · printSides: \(sheets * 2)
            layout: \(settings.layout.rawValue) · paper: \(settings.outputPaper.displayName)
            Print duplex (flip on short edge) on \(settings.outputPaper.displayName), fold along the centre line, then staple.
            """
        } catch {
            return BookletToolSupport.error(error, language: language)
        }
    }
}

enum BookletMakeError: LocalizedError {
    case outputExists(URL)

    var errorDescription: String? {
        switch self {
        case .outputExists(let url):
            "Output file already exists: \(url.path)"
        }
    }
}
