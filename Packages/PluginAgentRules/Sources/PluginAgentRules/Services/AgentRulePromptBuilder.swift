import Foundation
import ProviderAgentRules
import ProviderLLMContext

/// 把项目规则和插件贡献规则构造成一次请求的 system prompt。
public enum AgentRulePromptBuilder {
    /// 规则被预算截断时追加的提示。
    private static let truncationNotice = "… (rules truncated to fit the context budget)"

    /// 项目规则优先于插件规则；相同 ID 只注入一次。
    ///
    /// - Parameter maxTokens: 本轮允许注入的 token 上限。规则在上下文预算之后
    ///   才注入，因此必须自己收口；为 `nil` 时保持不设上限的旧行为。
    public static func buildPrompt(
        projectRules: [AgentRuleDefinition],
        contributedRules: [AgentRuleDefinition],
        maxTokens: Int? = nil
    ) -> String? {
        var seenIDs: Set<String> = []
        let sections = projectRules.map { ("Project", $0) } + contributedRules.map { ("Plugin", $0) }
        let uniqueSections = sections.compactMap { source, rule -> (String, AgentRuleDefinition)? in
            guard !rule.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !seenIDs.contains(rule.id) else { return nil }
            seenIDs.insert(rule.id)
            return (source, rule)
        }

        guard !uniqueSections.isEmpty else { return nil }

        let header = """
        ## Agent Rules
        Apply the following rules when they are relevant to the current task. Project rules take precedence over plugin rules with the same ID.
        """
        let ruleSections = uniqueSections.map { source, rule in
            """
            ### \(source) Rule: \(rule.title)
            \(rule.content.trimmingCharacters(in: .whitespacesAndNewlines))
            """
        }
        let fullPrompt = ([header] + ruleSections).joined(separator: "\n\n")

        guard let maxTokens else { return fullPrompt }
        guard LLMContextTokenEstimator.estimate(text: fullPrompt) > maxTokens else {
            return fullPrompt
        }
        return trimmedPrompt(header: header, sections: ruleSections, maxTokens: maxTokens)
    }

    // MARK: - Private

    /// 保留标题，按顺序装入能完整放下的规则，最后一条按剩余预算截断。
    private static func trimmedPrompt(
        header: String,
        sections: [String],
        maxTokens: Int
    ) -> String? {
        let headerTokens = LLMContextTokenEstimator.estimate(text: header)
        // 连标题都放不下时宁可不注入：hook 追加的内容同样必须落在预算内。
        guard headerTokens < maxTokens else { return nil }

        var result = header
        var used = headerTokens
        for section in sections {
            let candidate = result + "\n\n" + section
            let candidateTokens = LLMContextTokenEstimator.estimate(text: candidate)
            if candidateTokens <= maxTokens {
                result = candidate
                used = candidateTokens
                continue
            }

            let noticeTokens = LLMContextTokenEstimator.estimate(text: truncationNotice)
            // 预留分隔符与截断提示的位置，避免最终估算因取整反超预算。
            let remaining = maxTokens - used - noticeTokens - 8
            guard remaining > 0 else { break }
            let truncated = truncate(section, toTokens: remaining)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !truncated.isEmpty else { break }
            result += "\n\n" + truncated + "\n" + truncationNotice
            break
        }
        return result
    }

    /// 按 token 估算规则（UTF-8 字节数 / 3）截断到字符边界。
    private static func truncate(_ text: String, toTokens tokens: Int) -> String {
        guard tokens > 0 else { return "" }
        let maxBytes = tokens * 3
        var result = ""
        var bytes = 0
        for character in text {
            let cost = String(character).utf8.count
            guard bytes + cost <= maxBytes else { break }
            result.append(character)
            bytes += cost
        }
        return result
    }
}
