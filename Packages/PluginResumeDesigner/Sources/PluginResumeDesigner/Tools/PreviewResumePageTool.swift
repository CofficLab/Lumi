import AgentToolKit
import Foundation
import ResumeKit

public struct PreviewResumePageTool: SuperAgentTool {
    public let name = "resume_preview_page"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Render one resume page to PNG at an exact paper size and attach it for visual inspection."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = ResumeToolSupport.baseProperties()
        properties["pageIndex"] = ["type": "integer", "description": "Zero-based page index. Defaults to 0."]
        return ["type": "object", "properties": properties, "required": ["resumeId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Preview resume page"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    /// 覆盖默认实现：把渲染 PNG 作为图片附件放进结构化结果，供模型视觉检查。
    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        let language = ResumeToolSupport.language

        do {
            let storagePath = try await ResumeToolSupport.storagePath()
            let resume = try ResumeToolSupport.store.readResume(
                storagePath: storagePath,
                slug: try ResumeToolSupport.required("resumeId", arguments)
            )
            let pageIndex = ResumeToolSupport.int(arguments, "pageIndex") ?? 0
            let report = try ResumeToolSupport.store.lintResume(storagePath: storagePath, slug: resume.document.id)
            guard report.isValid else { throw ResumeStoreError.invalidHTML(report.errors) }
            // 导出管线会严格校验页面尺寸与溢出，命中即抛错。
            let data = try await ResumeHTMLExporter.exportPNG(
                html: resume.html,
                fileURL: resume.htmlURL,
                paper: resume.document.paper,
                pageIndex: pageIndex,
                dpi: ResumeExportResolution.screen.rawValue
            )
            let preset = ResumePaperSpec.preset(for: resume.document.paper)

            let content = ResumeToolSupport.localized(
                language,
                en: "Rendered resume page \(pageIndex + 1) at \(preset.cssWidth)x\(preset.cssHeight). The PNG is attached for visual inspection.",
                zh: "已渲染简历第 \(pageIndex + 1) 页（\(preset.cssWidth)x\(preset.cssHeight)）。PNG 已附加到工具结果中，可进行视觉检查。"
            )

            return ToolCallResult(
                content: content,
                images: [
                    ImageAttachment(
                        data: data,
                        mimeType: "image/png",
                        fileName: "\(resume.document.id)-p\(String(format: "%02d", pageIndex + 1)).png"
                    )
                ],
                isError: false
            )
        } catch {
            await MainActor.run {
                WorkspaceStore.shared.setError(error.localizedDescription)
            }
            return ToolCallResult(
                content: ResumeToolSupport.error(error, language: language),
                isError: true
            )
        }
    }
}
