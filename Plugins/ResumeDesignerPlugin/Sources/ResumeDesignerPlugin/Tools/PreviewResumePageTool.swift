import Foundation
import KernelLumi
import ResumeKit

public struct PreviewResumePageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "resume_preview_page",
        displayName: "Preview resume page",
        description: "Render one resume page to PNG at an exact paper size and attach it for visual inspection."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = ResumeToolSupport.baseProperties()
        properties["pageIndex"] = ["type": "integer", "description": "Zero-based page index. Defaults to 0."]
        return ["type": "object", "properties": .object(properties), "required": ["resumeId"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .low }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let storagePath = try await ResumeToolSupport.storagePath()
        let resume = try ResumeToolSupport.store.readResume(
            storagePath: storagePath,
            slug: try ResumeToolSupport.required("resumeId", arguments)
        )
        let pageIndex = (arguments["pageIndex"]?.stringValue).flatMap(Int.init) ?? 0
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
        kernel.attachImage(.init(
            mimeType: "image/png",
            base64Data: data.base64EncodedString(),
            fileName: "\(resume.document.id)-p\(String(format: "%02d", pageIndex + 1)).png"
        ))
        return "Rendered resume page \(pageIndex + 1) at \(preset.cssWidth)x\(preset.cssHeight). The PNG is attached for visual inspection."
    }
}
