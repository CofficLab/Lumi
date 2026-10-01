import Foundation
import KitAgentTool
import PDFKit

/// Merge several PDFs into one PDF in the order supplied by the caller.
public struct PDFMergeTool: SuperAgentTool {
    public let name = "pdf_merge"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Merge two or more PDF files into one PDF, preserving the supplied file order."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        BookletToolSupport.schema(
            [
                "sourcePaths": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Ordered absolute paths of the source PDF files. At least two are required.",
                ],
                "outputPath": BookletToolSupport.pathProperty(
                    "Absolute path of the merged PDF to write. Parent directories are created as needed."
                ),
                "overwrite": [
                    "type": "boolean",
                    "description": "Allow replacing an existing output file. Defaults to false.",
                ],
            ],
            required: ["sourcePaths", "outputPath"]
        )
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let count = BookletToolSupport.stringArray(arguments, "sourcePaths")?.count ?? 0
        return BookletToolSupport.localized(
            BookletToolSupport.language,
            en: "Merge \(count) PDF files",
            zh: "合并 \(count) 个 PDF 文件"
        )
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        BookletToolSupport.bool(arguments, "overwrite", default: false) ? .high : .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = BookletToolSupport.language
        do {
            guard let rawPaths = BookletToolSupport.stringArray(arguments, "sourcePaths") else {
                throw BookletToolSupport.ToolArgumentError.missing("sourcePaths")
            }
            guard rawPaths.count >= 2 else {
                throw PDFMerger.MergeError.tooFewSources
            }
            let sourceURLs = rawPaths.map(BookletToolSupport.fileURL)
            let outputURL = try BookletToolSupport.requiredPath("outputPath", arguments)
            let overwrite = BookletToolSupport.bool(arguments, "overwrite", default: false)
            let fileManager = FileManager.default
            let outputExists = fileManager.fileExists(atPath: outputURL.path)
            if outputExists, !overwrite {
                throw PDFMergeToolError.outputExists(outputURL)
            }

            let parentDirectory = outputURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            let stagingURL = parentDirectory.appendingPathComponent(
                ".merge-\(UUID().uuidString).pdf",
                isDirectory: false
            )
            defer { try? fileManager.removeItem(at: stagingURL) }

            let mergedURL = try await PDFMerger().merge(
                sourceURLs: sourceURLs,
                outputURL: stagingURL
            )
            if outputExists {
                _ = try fileManager.replaceItemAt(outputURL, withItemAt: mergedURL)
            } else {
                try fileManager.moveItem(at: mergedURL, to: outputURL)
            }

            let pageCount = sourceURLs.reduce(0) { total, url in
                total + (PDFDocument(url: url)?.pageCount ?? 0)
            }
            return """
            Merged \(sourceURLs.count) PDF files into one PDF.
            path: \(outputURL.path)
            pages: \(pageCount)
            """
        } catch {
            return BookletToolSupport.error(error, language: language)
        }
    }
}

enum PDFMergeToolError: LocalizedError {
    case outputExists(URL)

    var errorDescription: String? {
        switch self {
        case .outputExists(let url):
            "Output file already exists: \(url.path)"
        }
    }
}
