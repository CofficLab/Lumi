import Foundation
import LumiCoreKit

/// Bug修复子Agent
///
/// 专注于分析和修复代码中的bug。
/// 能够阅读代码、理解问题、定位错误根源并提供修复方案。
enum BugFixerAgent {
    static let definition = LumiSubAgentDefinition(
        id: "bug-fixer",
        displayName: "Bug Fixer",
        description: """
        PREFER this tool whenever the user reports a bug, crash, error, or unexpected \
        behavior — e.g. "this crashes", "throws an error", "wrong output", "doesn't work", \
        "fix this bug", "帮我修一下这个 bug".

        This tool delegates to an expert debugging sub-agent that autonomously:
        1. Reads the error message, stack trace, or behavior description you provide
        2. Locates the relevant source files and traces the root cause (off-by-one, \
        nil-handling, race conditions, logic errors, type mismatches, etc.)
        3. Applies a focused fix via edit_file and explains why it works

        Do NOT try to debug by yourself using shell + read_file loops — the sub-agent \
        follows a structured root-cause workflow (symptoms → analysis → fix → verification) \
        and produces a definitive diagnosis + fix in one delegation.

        Examples of when to use this tool:
        - "Fix this crash: NSInvalidArgumentException ..."
        - "The login flow returns nil when credentials are expired — fix it"
        - "帮我修这个 bug：返回值错了"
        - "为什么这个函数在 empty input 时崩溃？"

        Pass the task as an error message, stack trace, or a description of the \
        unexpected behavior. Include repro steps and expected vs. actual behavior \
        when possible (e.g. "calling parseDate('2024-13-01') crashes; should return nil"). \
        The sub-agent may also run shell / tests to verify the fix.
        """,
        providerID: "stepfun",
        modelID: "step-3.7-flash",
        systemPrompt: """
            You are a debugging specialist. Your job is to analyze bugs and provide fixes.

            Workflow:
            1. Understand the problem:
               - Read error messages or stack traces
               - Read the relevant code using read_file tool
               - Identify the symptoms and expected behavior

            2. Analyze the root cause:
               - Trace through the code logic
               - Check for common bug patterns:
                 * Off-by-one errors
                 * Null/nil pointer issues
                 * Race conditions
                 * Resource leaks
                 * Logic errors
                 * Type mismatches
               - Consider edge cases

            3. Propose fixes:
               - Explain the root cause clearly
               - Provide specific code changes using edit_file
               - Consider the impact on other parts of the code
               - Suggest tests to verify the fix

            4. Verify the solution:
               - Ensure the fix addresses the root cause, not just symptoms
               - Consider potential side effects
               - Suggest how to prevent similar bugs in the future

            Output format:
            - Root cause analysis
            - The fix applied
            - Explanation of why this fixes the issue
            - Suggestions for preventing similar bugs

            Be methodical and thorough in your analysis.
            """,
        requiredTags: [.fileSystem, .git, .shell],
        excludedTags: [.network, .sideEffect],
        excludedToolNames: ["git_push"],
        maxTurns: 15,
        iconName: "ladybug"
    )
}
