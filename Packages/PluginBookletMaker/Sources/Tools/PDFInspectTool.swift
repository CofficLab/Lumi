import Foundation
import KitAgentTool

/// 读取 PDF 基本信息（页数、页面尺寸、加密状态），并在给定拼版参数下
/// 预先给出物理纸张数与逐面页序映射，供后续 `booklet_make` 决策。
public struct PDFInspectTool: SuperAgentTool {
    public let name = "pdf_inspect"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Read a PDF file's page count, page size and encryption state, then return the imposition plan (physical sheets and page order) for the given booklet settings. Read-only."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = BookletToolSupport.settingsProperties()
        properties["path"] = BookletToolSupport.pathProperty(
            "Absolute path of the source PDF file."
        )
        return BookletToolSupport.schema(properties, required: ["path"])
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let name = BookletToolSupport.string(arguments, "path").map { URL(fileURLWithPath: $0).lastPathComponent }
        return BookletToolSupport.localized(
            BookletToolSupport.language,
            en: "Inspect PDF \(name ?? "")",
            zh: "检查 PDF \(name ?? "")"
        )
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    /// 只读取源 PDF，不写入任何文件，可与其他只读工具并发。
    public var executionCapability: ToolExecutionCapability { .parallelReadOnly }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = BookletToolSupport.language
        let url = try BookletToolSupport.requiredPath("path", arguments)

        do {
            let info = try await PDFInspector().inspect(url)
            let settings = try BookletToolSupport.validatedSettings(arguments)
            return """
            Inspected PDF: \(url.path)
            pages: \(info.pageCount)
            pageSize: \(BookletToolSupport.millimetres(info.firstPageSize.width))mm × \(BookletToolSupport.millimetres(info.firstPageSize.height))mm (first page, cropBox)
            encrypted: no

            \(BookletToolSupport.planDescription(inputPageCount: info.pageCount, settings: settings))
            """
        } catch {
            return BookletToolSupport.error(error, language: language)
        }
    }
}
