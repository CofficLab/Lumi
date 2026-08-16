import AgentToolKit
import Foundation
import ResumeKit

/// 静态 lint + 运行时分页测量：页数、页面尺寸与内容溢出。
public struct LintResumeTool: SuperAgentTool {
    public let name = "resume_lint"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Validate resume HTML statically and measure pagination at runtime (page count, paper-size match, content overflow)."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": ResumeToolSupport.baseProperties(), "required": ["resumeId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Lint resume"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let storagePath = try await ResumeToolSupport.storagePath()
        let resumeID = try ResumeToolSupport.required("resumeId", arguments)
        let resume = try ResumeToolSupport.store.readResume(storagePath: storagePath, slug: resumeID)
        let report = try ResumeToolSupport.store.lintResume(storagePath: storagePath, slug: resumeID)

        var lines: [String] = ["resumeId=\(resumeID)"]
        lines.append(report.errors.isEmpty ? "Static lint: PASS" : "Static lint: FAIL")
        lines.append(contentsOf: report.errors.map { "ERROR [\($0.code)] \($0.message)" })
        lines.append(contentsOf: report.warnings.map { "WARN [\($0.code)] \($0.message)" })

        // 运行时测量：页数 / 尺寸 / 溢出（测量失败不算 lint 失败，单独报告）。
        do {
            let inspection = try await ResumeHTMLExporter.inspectPages(
                html: resume.html,
                fileURL: resume.htmlURL,
                paper: resume.document.paper
            )
            let preset = ResumePaperSpec.preset(for: resume.document.paper)
            let sizeMismatches = inspection.pages.filter {
                abs($0.width - Double(preset.cssWidth)) > 1 || abs($0.height - Double(preset.cssHeight)) > 1
            }
            lines.append("Pagination: \(inspection.pageCount) page(s) at \(preset.cssWidth)x\(preset.cssHeight) px")
            if !sizeMismatches.isEmpty {
                let detail = sizeMismatches.map { "page \($0.index + 1) renders \($0.width)x\($0.height)" }.joined(separator: "; ")
                lines.append("ERROR [page_size_mismatch] \(detail)")
            }
            if !inspection.overflowingPages.isEmpty {
                let pages = inspection.overflowingPages.map { String($0 + 1) }.joined(separator: ", ")
                lines.append("ERROR [page_overflow] content overflows page(s) \(pages); trim content or add another .resume-page container")
            }
            if sizeMismatches.isEmpty && inspection.overflowingPages.isEmpty {
                lines.append("Pagination: PASS")
            }
        } catch {
            lines.append("WARN [pagination_unavailable] runtime measurement failed: \(error.localizedDescription)")
        }

        let hasErrors = !report.errors.isEmpty || lines.contains { $0.hasPrefix("ERROR") }
        return lines.joined(separator: "\n") + (hasErrors ? "\nOverall: FAIL" : "\nOverall: PASS")
    }
}
