import KitAgentTool
import Foundation

public struct LintIconDocumentTool: SuperAgentTool {
    public let name = "lint_icon_document"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Check the current icon document for export quality issues and return errors and warnings."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": IconToolSupport.baseProperties()]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Lint icon document"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let language = IconToolSupport.language
        do {
            let (document, scope) = try await IconToolSupport.resolveDocument(arguments)

            let report = IconDocumentLinter().lint(document)
            if report.issues.isEmpty {
                return IconToolSupport.localized(
                    language,
                    en: """
                    Icon document passed quality checks.
                    scope=\(scope.rawValue)
                    documentId: \(document.id)
                    exportable: true
                    """,
                    zh: """
                    图标文档已通过质量检查。
                    作用域: \(scope.rawValue)
                    文档ID: \(document.id)
                    可导出: true
                    """
                )
            }

            let lines = report.issues.map { issue in
                let severity = localizedSeverity(issue.severity, language: language)
                let layerSuffix = issue.layerId.map {
                    IconToolSupport.localized(language, en: " layerId=\($0)", zh: " 图层ID=\($0)")
                } ?? ""
                return "- [\(severity)]\(layerSuffix) \(issue.message)"
            }.joined(separator: "\n")

            return IconToolSupport.localized(
                language,
                en: """
                Icon document quality report.
                scope=\(scope.rawValue)
                documentId: \(document.id)
                exportable: \(report.isExportable)
                \(lines)
                """,
                zh: """
                图标文档质量报告。
                作用域: \(scope.rawValue)
                文档ID: \(document.id)
                可导出: \(report.isExportable)
                \(lines)
                """
            )
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return IconToolSupport.error(error, language: language)
        }
    }

    private func localizedSeverity(_ severity: IconDocumentLintIssue.Severity, language: LanguagePreference) -> String {
        switch severity {
        case .warning:
            IconToolSupport.localized(language, en: "warning", zh: "警告")
        case .error:
            IconToolSupport.localized(language, en: "error", zh: "错误")
        }
    }
}
