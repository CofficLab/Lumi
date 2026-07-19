import Foundation
import LumiKernel

/// 代码审查子Agent
///
/// 专注于代码质量检查、最佳实践建议和潜在问题识别。
/// 使用只读工具分析代码，提供改进建议。
enum CodeReviewAgent {
    static let definition = LumiSubAgentDefinition(
        id: "code-reviewer",
        displayName: "Code Reviewer",
        description: """
        PREFER this tool whenever the user asks for a "code review", "review my code", \
        "check the quality" of recent changes, or "is there any issue with this code".

        This tool delegates to an expert senior-reviewer sub-agent that autonomously:
        1. Reads the relevant files (or diff range you specify) using read-only tools
        2. Analyzes for code quality, bugs, performance, security, and Swift best practices
        3. Produces a structured review with Critical / Warning / Suggestion categories \
        and concrete improvement examples

        Do NOT try to review by reading files yourself and listing issues — the sub-agent \
        enforces a consistent review checklist (force unwraps, error handling, naming, \
        memory management, API design) and produces a higher-quality report in one delegation.

        Examples of when to use this tool:
        - "帮我 review 一下最近的改动"
        - "Code review this PR / this file"
        - "Check if there are any bugs in this module"
        - "看看这段代码有没有什么问题"

        Pass the task as a file path, diff range, or "the recent uncommitted changes". \
        Include any focus areas if applicable (e.g. "review this PR focused on concurrency \
        and error handling" or "check this new API for breaking changes").
        """,
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
        requiredTags: [.fileSystem, .git, .readOnly],
        excludedTags: [.destructive, .network, .sideEffect],
        excludedToolNames: ["git_commit", "git_push"],
        maxTurns: 10,
        iconName: "doc.text.magnifyingglass"
    )
}
