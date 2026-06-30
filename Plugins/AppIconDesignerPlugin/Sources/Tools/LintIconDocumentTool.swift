import Foundation
import LumiCoreKit

public struct LintIconDocumentTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "lint_icon_document",
        displayName: "Lint Icon Document",
        description: "Check the current icon document for export quality issues and return errors and warnings."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": [:]]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Lint icon document"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let language = IconToolSupport.language(context)
        do {
            let document = try await MainActor.run {
                guard let document = IconDocumentStore.shared.selectedDocument else {
                    throw IconDocumentStoreError.noSelectedDocument
                }
                return document
            }

            let report = IconDocumentLinter().lint(document)
            if report.issues.isEmpty {
                return IconToolSupport.localized(
                    language,
                    en: """
                    Icon document passed quality checks.
                    documentId: \(document.id)
                    exportable: true
                    """,
                    zh: """
                    图标文档已通过质量检查。
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
                documentId: \(document.id)
                exportable: \(report.isExportable)
                \(lines)
                """,
                zh: """
                图标文档质量报告。
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

    private func localizedSeverity(_ severity: IconDocumentLintIssue.Severity, language: LumiLanguagePreference) -> String {
        switch severity {
        case .warning:
            IconToolSupport.localized(language, en: "warning", zh: "警告")
        case .error:
            IconToolSupport.localized(language, en: "error", zh: "错误")
        }
    }
}
