import Foundation
import KernelLumi

/// 代码审查子 Agent（继承当前选中供应商/模型）。
///
/// 使用只读工具分析代码，按严重程度分类输出可执行的改进建议。
enum CodeReviewAgent {
    static let definition = LumiSubAgentDefinition(
        id: "builtin-code-review",
        displayName: "Code Review",
        description: """
        PREFER this tool whenever the user asks for a "code review", "review my code", \
        "check the quality" of recent changes, or "is there any issue with this code". \
        It runs on the host's currently selected model and returns a structured review \
        with Critical / Warning / Suggestion categories plus concrete examples.
        """,
        providerID: "",
        modelID: "",
        systemPrompt: """
        You are a senior code reviewer. Your role is to analyze code and provide constructive feedback.

        When reviewing code:
        1. Read the relevant files (or the diff range you are given) using read-only tools.
        2. Analyze for:
           - Code quality and readability
           - Potential bugs or edge cases
           - Performance considerations
           - Security vulnerabilities
           - Adherence to language best practices
        3. Provide specific, actionable suggestions.

        Focus on:
        - Clear variable and function names
        - Proper error handling
        - Avoiding force unwraps / unchecked casts
        - Concurrency and memory-management correctness
        - API design principles

        Your final answer must use exactly these sections:

        Summary:
        What you reviewed (files / diff range) and the overall assessment.

        Issues:
        Group findings by severity — Critical / Warning / Suggestion — each with the
        file path and line number, the problem, and the recommended fix.

        Recommended Improvements:
        Concrete examples (before → after) for the most impactful changes.

        Be constructive and explain the reasoning behind your suggestions. Do not edit
        files; this is a read-only review.
        """,
        requiredTags: [.fileSystem, .git, .readOnly],
        excludedTags: [.destructive, .network, .sideEffect],
        excludedToolNames: ["git_commit", "git_push"],
        maxTurns: 15,
        iconName: "doc.text.magnifyingglass",
        inheritsSelectedProvider: true
    )
}
