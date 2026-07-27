import Foundation

/// Prompt 语言模板
private struct PromptTemplate: Sendable {
    let disclaimer: String
    let projectPathLabel: String
    let snippetsHeader: String
    let snippetLabel: @Sendable (Int) -> String
    let sourceLabel: String
    let truncationNote: String

    static let chinese = PromptTemplate(
        disclaimer: "以下上下文仅供参考，可能存在不准确的情况。",
        projectPathLabel: "项目路径",
        snippetsHeader: "相关片段",
        snippetLabel: { index in "[片段 \(index)]" },
        sourceLabel: "来源",
        truncationNote: "[说明] 由于上下文预算限制，已截断部分片段。"
    )

    static let english = PromptTemplate(
        disclaimer: "The following context is for reference only and may contain inaccuracies.",
        projectPathLabel: "Project path",
        snippetsHeader: "Relevant snippets",
        snippetLabel: { index in "[Snippet \(index)]" },
        sourceLabel: "Source",
        truncationNote: "[Note] Some snippets were truncated due to the context budget."
    )
}

public enum RAGContextBuilder {
    private static let maxContextChars = 9000

    public static func buildPrompt(
        query: String,
        results: [RAGSearchResult],
        projectPath: String?,
        languagePreference: RAGLanguagePreference = .chinese
    ) -> String {
        let template: PromptTemplate = languagePreference == .chinese ? .chinese : .english
        return buildPrompt(query: query, results: results, projectPath: projectPath, template: template)
    }

    private static func buildPrompt(
        query: String,
        results: [RAGSearchResult],
        projectPath: String?,
        template: PromptTemplate
    ) -> String {
        var prompt = "\(template.disclaimer)\n\n"
        if let projectPath, !projectPath.isEmpty {
            prompt += "\(template.projectPathLabel)：\(projectPath)\n\n"
        }
        prompt += "---\n\(template.snippetsHeader)：\n"

        var usedChars = 0
        var includedCount = 0
        for (index, result) in results.enumerated() {
            let budget = max(maxContextChars - usedChars, 0)
            if budget == 0 { break }
            let clipped = clip(result.content, maxChars: min(3000, budget))
            if clipped.isEmpty { continue }

            prompt += "\n\(template.snippetLabel(index + 1)) \(template.sourceLabel)：\(result.source)\n"
            prompt += "\(clipped)\n"
            usedChars += clipped.count
            includedCount += 1
        }

        if includedCount < results.count {
            prompt += "\n\(template.truncationNote)\n"
        }
        return prompt
    }

    private static func clip(_ text: String, maxChars: Int) -> String {
        guard maxChars > 0 else { return "" }
        if text.count <= maxChars { return text }
        let end = text.index(text.startIndex, offsetBy: maxChars)
        return String(text[..<end]) + "\n...[truncated]"
    }
}
