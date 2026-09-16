import Foundation
import KitAgentTool

/// 按切点把一份 PDF 拆成多个 PDF 文件。
///
/// 切点是「切在第几页之后」的 1-based 页号：`[20, 50]` 会把 100 页的
/// 文档拆成 1–20、21–50、51–100 三段。
public struct PDFSplitTool: SuperAgentTool {
    public let name = "pdf_split"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Split one PDF into several PDF files at the given page cut points. Each cut point is a 1-based page number after which the split happens."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let properties: [String: Any] = [
            "sourcePath": BookletToolSupport.pathProperty(
                "Absolute path of the source PDF file."
            ),
            "outputDirectory": BookletToolSupport.pathProperty(
                "Absolute directory that receives the split PDF files. Created if missing."
            ),
            "cutPoints": [
                "type": "array",
                "items": ["type": "integer"],
                "description": "1-based page numbers after which to split, e.g. [20, 50]. Values must be >= 1 and less than the page count.",
            ],
            "baseName": [
                "type": "string",
                "description": "Optional file name stem. Defaults to the source file name without extension.",
            ],
            "overwrite": [
                "type": "boolean",
                "description": "Allow replacing existing output files. Defaults to false.",
            ],
        ]
        return BookletToolSupport.schema(
            properties,
            required: ["sourcePath", "outputDirectory", "cutPoints"]
        )
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let name = BookletToolSupport.string(arguments, "sourcePath")
            .map { URL(fileURLWithPath: $0).lastPathComponent }
        return BookletToolSupport.localized(
            BookletToolSupport.language,
            en: "Split PDF \(name ?? "")",
            zh: "拆分 PDF \(name ?? "")"
        )
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        BookletToolSupport.bool(arguments, "overwrite", default: false) ? .high : .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = BookletToolSupport.language
        let sourceURL = try BookletToolSupport.requiredPath("sourcePath", arguments)
        let outputDirectory = try BookletToolSupport.requiredPath("outputDirectory", arguments)
        let overwrite = BookletToolSupport.bool(arguments, "overwrite", default: false)

        do {
            guard let rawCutPoints = BookletToolSupport.intArray(arguments, "cutPoints") else {
                throw BookletToolSupport.ToolArgumentError.missing("cutPoints")
            }
            let info = try await PDFInspector().inspect(sourceURL)

            // 复用与 UI 完全相同的校验与分段逻辑，避免两套规则漂移。
            let cutPoints = try Self.validatedCutPoints(rawCutPoints, pageCount: info.pageCount)
            let segments = PDFSplitPlan.segments(pageCount: info.pageCount, cutPoints: cutPoints)

            let baseName = BookletToolSupport.string(arguments, "baseName")?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty ?? sourceURL.deletingPathExtension().lastPathComponent
            let outputs = segments.map {
                PDFSplitOutput(segment: $0, fileName: $0.fileName(baseName: baseName))
            }

            let fileManager = FileManager.default
            try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

            // PDFSplitter 拒绝覆盖已存在文件；overwrite 时先清理目标。
            if overwrite {
                for output in outputs {
                    let url = outputDirectory.appendingPathComponent(output.fileName)
                    if fileManager.fileExists(atPath: url.path) {
                        try fileManager.removeItem(at: url)
                    }
                }
            }

            let urls = try await PDFSplitter().split(
                sourceURL: sourceURL,
                outputDirectory: outputDirectory,
                outputs: outputs
            )

            return """
            Split \(info.pageCount) pages into \(urls.count) PDF files.
            \(BookletToolSupport.segmentsDescription(outputs))
            """
        } catch {
            return BookletToolSupport.error(error, language: language)
        }
    }

    /// 越界或非正切点直接报错，而不是被静默丢弃。
    private static func validatedCutPoints(_ raw: [Int], pageCount: Int) throws -> [Int] {
        for point in raw {
            guard point >= 1, point < pageCount else {
                throw BookletToolSupport.ToolArgumentError.invalid(
                    "cutPoints (must be between 1 and \(max(pageCount - 1, 0)), found \(point))"
                )
            }
        }
        return Array(Set(raw)).sorted()
    }
}
