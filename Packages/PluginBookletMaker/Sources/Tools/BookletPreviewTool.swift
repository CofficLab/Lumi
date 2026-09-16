import Foundation
import KitAgentTool

/// 以当前拼版参数渲染小册子的前若干个印刷面为 PNG 预览图，
/// 供模型在真正导出前做视觉确认（页序、留白、裁切标记）。
public struct BookletPreviewTool: SuperAgentTool {
    public let name = "booklet_preview"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Render the first few print sides of an imposed booklet as PNG images and attach them for visual inspection. Does not write any permanent output file."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = BookletToolSupport.settingsProperties()
        properties["path"] = BookletToolSupport.pathProperty(
            "Absolute path of the source PDF file."
        )
        properties["maxSides"] = [
            "type": "integer",
            "description": "How many print sides to render. Defaults to 4, capped at 12.",
        ]
        properties["maxPixelWidth"] = [
            "type": "number",
            "description": "Rendered PNG width in pixels. Defaults to 900.",
        ]
        return BookletToolSupport.schema(properties, required: ["path"])
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let name = BookletToolSupport.string(arguments, "path")
            .map { URL(fileURLWithPath: $0).lastPathComponent }
        return BookletToolSupport.localized(
            BookletToolSupport.language,
            en: "Preview booklet \(name ?? "PDF")",
            zh: "预览小册子 \(name ?? "PDF")"
        )
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    /// 只写插件暂存目录下的临时文件，可与其它只读工具并发。
    public var executionCapability: ToolExecutionCapability { .parallelReadOnly }

    /// 覆盖默认实现：把渲染出的 PNG 作为图片附件放进结构化结果。
    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        let language = BookletToolSupport.language
        let sourceURL = try BookletToolSupport.requiredPath("path", arguments)

        do {
            let settings = try BookletToolSupport.validatedSettings(arguments)
            let info = try await PDFInspector().inspect(sourceURL)

            let requestedSides = BookletToolSupport.int(arguments, "maxSides") ?? 4
            let maxSides = min(max(requestedSides, 1), 12)
            let pixelWidth = BookletToolSupport.double(arguments, "maxPixelWidth", default: 900)
            guard pixelWidth > 0 else {
                throw BookletToolSupport.ToolArgumentError.invalid("maxPixelWidth")
            }

            let availableSides = BookletLayoutEngine.buildOutputSides(
                inputPageCount: info.pageCount,
                settings: settings
            ).count
            let renderCount = min(maxSides, availableSides)
            guard renderCount > 0 else {
                throw ToolArgumentError.noRenderablePages
            }

            // 渲染到插件暂存目录：预览是一次性产物，不污染用户目录。
            let jobDirectory = BookletToolSupport
                .stagingDirectory(named: "agent-preview")
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: jobDirectory) }

            let imposedURL = jobDirectory.appendingPathComponent("imposed.pdf")
            _ = try await BookletRenderer().render(
                sourceURL: sourceURL,
                outputURL: imposedURL,
                settings: settings
            )

            let thumbnails = await BookletThumbnailer().makeThumbnails(
                fromPDF: imposedURL,
                count: renderCount,
                maxPixelWidth: pixelWidth,
                outputDirectory: jobDirectory
            )

            var images: [ImageAttachment] = []
            for thumbnail in thumbnails {
                guard let data = try? Data(contentsOf: thumbnail.fileURL) else { continue }
                images.append(ImageAttachment(
                    data: data,
                    mimeType: "image/png",
                    fileName: "booklet-side-\(thumbnail.sheetIndex + 1).png"
                ))
            }

            let content = """
            Rendered \(images.count) of \(availableSides) print sides for visual inspection.
            sourcePages: \(info.pageCount) · layout: \(settings.layout.rawValue) · paper: \(settings.outputPaper.displayName)

            \(BookletToolSupport.planDescription(inputPageCount: info.pageCount, settings: settings))

            Each attached PNG is one output print side; sides pair up as front/back of one physical sheet.
            """
            return ToolCallResult(content: content, images: images, isError: false)
        } catch {
            return ToolCallResult(
                content: BookletToolSupport.error(error, language: language),
                isError: true
            )
        }
    }

    private enum ToolArgumentError: LocalizedError {
        case noRenderablePages

        var errorDescription: String? {
            switch self {
            case .noRenderablePages: "Source PDF has no renderable pages."
            }
        }
    }
}
