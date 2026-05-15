import Foundation

struct ReviewEngine: Sendable {
    let llmService: LLMService
    let config: LLMConfig

    func review(context: ReviewContext) async throws -> ReviewReport {
        guard context.hasChanges else {
            return ReviewReport(
                id: UUID(),
                repositoryPath: context.repositoryPath,
                scope: context.scope,
                baseCommitHash: nil,
                diffStats: context.diffStats,
                overallScore: 10,
                summary: "No changes to review.",
                issues: [],
                suggestions: [],
                createdAt: Date()
            )
        }

        let conversationId = UUID()
        let messages = [
            ChatMessage(role: .system, conversationId: conversationId, content: systemPrompt),
            ChatMessage(role: .user, conversationId: conversationId, content: userPrompt(context: context))
        ]

        let response = try await llmService.sendMessage(messages: messages, config: config)
        return try parseReport(response.content, context: context)
    }

    private var systemPrompt: String {
        """
        You are a senior code reviewer. Review only the provided Git diff.
        Focus on real bugs, security issues, performance risks, maintainability, style issues, and missing tests.
        Avoid speculative findings. Every finding must be actionable and tied to changed code.
        Return only valid JSON. Do not wrap the JSON in Markdown.

        JSON schema:
        {
          "overallScore": 0.0,
          "summary": "short summary",
          "issues": [
            {
              "severity": "critical|warning|info",
              "category": "bug|security|performance|style|test|maintainability",
              "file": "relative/path",
              "line": 12,
              "range": { "start": 12, "end": 16 },
              "description": "what is wrong",
              "rationale": "why it matters",
              "fixSuggestion": "specific fix",
              "suggestedPatch": "optional unified diff patch",
              "confidence": 0.0
            }
          ],
          "suggestions": [
            {
              "title": "short title",
              "description": "actionable suggestion",
              "suggestedPatch": "optional unified diff patch"
            }
          ]
        }
        """
    }

    private func userPrompt(context: ReviewContext) -> String {
        """
        ## Project Context
        \(context.projectContext)

        ## Project Rules
        \(context.projectRules)

        ## Review Scope
        \(context.scope.rawValue)

        ## Diff Stats
        Files changed: \(context.diffStats.filesChanged)
        Insertions: \(context.diffStats.insertions)
        Deletions: \(context.diffStats.deletions)
        Truncated: \(context.truncated)

        ## Changed Files
        \(context.changedFiles.map { "- \($0)" }.joined(separator: "\n"))

        ## Git Diff
        ```diff
        \(context.diffContent)
        ```
        """
    }

    private func parseReport(_ content: String, context: ReviewContext) throws -> ReviewReport {
        let json = try extractJSONObject(from: content)
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(ReviewReportPayload.self, from: data)
        let changedFiles = Set(context.changedFiles)

        let issues = decoded.issues.map { payload -> ReviewIssue in
            let confidence = min(max(payload.confidence ?? 0.5, 0), 1)
            let severity = confidence < 0.45 ? .info : (ReviewSeverity(rawValue: payload.severity ?? "") ?? .info)
            let category = ReviewCategory(rawValue: payload.category ?? "") ?? .maintainability
            let file = payload.file ?? ""

            return ReviewIssue(
                id: UUID(),
                severity: changedFiles.isEmpty || changedFiles.contains(file) ? severity : .info,
                category: category,
                file: file,
                line: payload.line,
                range: payload.range,
                description: payload.description ?? "No description provided.",
                rationale: payload.rationale ?? "",
                fixSuggestion: payload.fixSuggestion,
                suggestedPatch: payload.suggestedPatch,
                confidence: confidence
            )
        }

        let suggestions = decoded.suggestions.map {
            ReviewSuggestion(
                id: UUID(),
                title: $0.title ?? "Suggestion",
                description: $0.description ?? "",
                suggestedPatch: $0.suggestedPatch
            )
        }

        return ReviewReport(
            id: UUID(),
            repositoryPath: context.repositoryPath,
            scope: context.scope,
            baseCommitHash: nil,
            diffStats: context.diffStats,
            overallScore: min(max(decoded.overallScore ?? 0, 0), 10),
            summary: decoded.summary ?? "Review completed.",
            issues: issues,
            suggestions: suggestions,
            createdAt: Date()
        )
    }

    private func extractJSONObject(from content: String) throws -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }

        guard let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") else {
            throw ReviewEngineError.invalidJSONResponse
        }

        return String(trimmed[start...end])
    }
}

private struct ReviewReportPayload: Codable {
    let overallScore: Double?
    let summary: String?
    let issues: [ReviewIssuePayload]
    let suggestions: [ReviewSuggestionPayload]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overallScore = try container.decodeIfPresent(Double.self, forKey: .overallScore)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        issues = try container.decodeIfPresent([ReviewIssuePayload].self, forKey: .issues) ?? []
        suggestions = try container.decodeIfPresent([ReviewSuggestionPayload].self, forKey: .suggestions) ?? []
    }
}

private struct ReviewIssuePayload: Codable {
    let severity: String?
    let category: String?
    let file: String?
    let line: Int?
    let range: ReviewLineRange?
    let description: String?
    let rationale: String?
    let fixSuggestion: String?
    let suggestedPatch: String?
    let confidence: Double?
}

private struct ReviewSuggestionPayload: Codable {
    let title: String?
    let description: String?
    let suggestedPatch: String?
}

enum ReviewEngineError: LocalizedError {
    case invalidJSONResponse

    var errorDescription: String? {
        switch self {
        case .invalidJSONResponse:
            return "The model did not return a valid JSON review report."
        }
    }
}
