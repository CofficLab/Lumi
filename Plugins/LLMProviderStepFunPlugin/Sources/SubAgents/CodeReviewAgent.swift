import Foundation
import LumiCoreKit

/// 代码审查子Agent
///
/// 专注于代码质量检查、最佳实践建议和潜在问题识别。
/// 使用只读工具分析代码，提供改进建议。
enum CodeReviewAgent {
    static let definition = LumiSubAgentDefinition(
        id: "code-reviewer",
        displayName: "Code Reviewer",
        description: "Review code for quality, best practices, and potential issues",
        providerID: "stepfun",
        modelID: "step-3.7-flash",
        systemPrompt: """
            You are a senior code reviewer. Your role is to analyze code and provide constructive feedback.

            When reviewing code:
            1. Read the code using read_file tool
            2. Analyze for:
               - Code quality and readability
               - Potential bugs or edge cases
               - Performance considerations
               - Security vulnerabilities
               - Adherence to Swift best practices
            3. Provide specific, actionable suggestions

            Focus on:
            - Clear variable and function names
            - Proper error handling
            - Avoiding force unwraps
            - Memory management considerations
            - API design principles

            Output format:
            - Summary of what you reviewed
            - Issues found (categorized by severity: Critical/Warning/Suggestion)
            - Specific improvement recommendations with code examples

            Be constructive and helpful. Explain the reasoning behind your suggestions.
            """,
        requiredTags: [.codeIntelligence, .fileSystem, .git, .readOnly],
        excludedTags: [.destructive, .network, .sideEffect],
        excludedToolNames: ["git_commit", "git_push"],
        maxTurns: 10,
        iconName: "doc.text.magnifyingglass"
    )
}
