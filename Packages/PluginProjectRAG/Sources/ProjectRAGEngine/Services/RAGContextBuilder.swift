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

    /// 构建注入 prompt。
    ///
    /// - `maxTokens == nil`：保留 9000 字符上限的旧行为，始终返回非 nil。
    /// - `maxTokens != nil`：按 token 预算从尾部逐个移除完整片段直到达标；
    ///   连 disclaimer 都放不下时返回 nil，调用方应跳过注入。预算 ≤ 0 直接返回 nil。
    ///   `tokenEstimator` 缺省用保守的 UTF-8 字节估算（与 ProviderLLMContext 同式），
    ///   Engine 不依赖 ProviderLLMContext。
    public static func buildPrompt(
        query: String,
        results: [RAGSearchResult],
        projectPath: String?,
        languagePreference: RAGLanguagePreference = .chinese,
        maxTokens: Int? = nil,
        tokenEstimator: ((String) -> Int)? = nil
    ) -> String? {
        let template: PromptTemplate = languagePreference == .chinese ? .chinese : .english
        return buildPrompt(
            query: query,
            results: results,
            projectPath: projectPath,
            template: template,
            maxTokens: maxTokens,
            tokenEstimator: tokenEstimator
        )
    }

    private static func buildPrompt(
        query: String,
        results: [RAGSearchResult],
        projectPath: String?,
        template: PromptTemplate,
        maxTokens: Int?,
        tokenEstimator: ((String) -> Int)?
    ) -> String? {
        var header = "\(template.disclaimer)\n\n"
        if let projectPath, !projectPath.isEmpty {
            header += "\(template.projectPathLabel)：\(projectPath)\n\n"
        }
        header += "---\n\(template.snippetsHeader)：\n"

        var blocks: [String] = []
        var usedChars = 0
        for (index, result) in results.enumerated() {
            let budget = max(maxContextChars - usedChars, 0)
            if budget == 0 { break }
            let clipped = clip(result.content, maxChars: min(3000, budget))
            if clipped.isEmpty { continue }

            let lineLabel = result.lineRange.map { ":\($0.startLine)-\($0.endLine)" } ?? ""
            var block = "\n\(template.snippetLabel(index + 1)) \(template.sourceLabel)：\(result.source)\(lineLabel) [evidence: \(result.matchKind.rawValue)]\n"
            block += "\(clipped)\n"
            blocks.append(block)
            usedChars += clipped.count
        }

        let charDropped = blocks.count < results.count
        func assemble(_ blocks: [String], dropped: Bool) -> String {
            var prompt = header + blocks.joined()
            if dropped {
                prompt += "\n\(template.truncationNote)\n"
            }
            return prompt
        }

        guard let maxTokens else {
            return assemble(blocks, dropped: charDropped)
        }
        guard maxTokens > 0 else { return nil }

        let estimate = tokenEstimator ?? { text in
            max(Int(ceil(Double(text.utf8.count) / 3.0)), 1)
        }
        var dropped = charDropped
        var prompt = assemble(blocks, dropped: dropped)
        while estimate(prompt) > maxTokens {
            if blocks.isEmpty {
                return estimate(header) <= maxTokens ? header : nil
            }
            blocks.removeLast()
            dropped = true
            prompt = assemble(blocks, dropped: dropped)
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
