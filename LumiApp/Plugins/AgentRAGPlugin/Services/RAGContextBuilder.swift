import Foundation

enum RAGContextBuilder {
    private static let maxContextChars = 9000

    static func buildPrompt(query: String, results: [RAGSearchResult], projectPath: String?) -> String {
        var prompt = "基于以下代码上下文回答用户问题。\n\n"
        if let projectPath, !projectPath.isEmpty {
            prompt += "项目路径：\(projectPath)\n\n"
        }
        prompt += "---\n相关片段：\n"

        var usedChars = 0
        var includedCount = 0
        for (index, result) in results.enumerated() {
            let budget = max(maxContextChars - usedChars, 0)
            if budget == 0 { break }
            let clipped = clip(result.content, maxChars: min(3000, budget))
            if clipped.isEmpty { continue }

            prompt += "\n[片段 \(index + 1)] 来源：\(result.source)\n"
            prompt += "\(clipped)\n"
            usedChars += clipped.count
            includedCount += 1
        }

        if includedCount < results.count {
            prompt += "\n[说明] 由于上下文预算限制，已截断部分片段。\n"
        }
        prompt += "\n---\n用户问题：\(query)\n"
        prompt += "请优先依据上述片段回答，并在答案中明确引用来源文件。"
        return prompt
    }

    private static func clip(_ text: String, maxChars: Int) -> String {
        guard maxChars > 0 else { return "" }
        if text.count <= maxChars { return text }
        let end = text.index(text.startIndex, offsetBy: maxChars)
        return String(text[..<end]) + "\n...[truncated]"
    }
}
