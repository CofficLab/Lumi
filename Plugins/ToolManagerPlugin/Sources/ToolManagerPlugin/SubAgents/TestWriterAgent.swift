import Foundation
import LumiKernel

/// 写测试子 Agent（继承当前选中供应商/模型）。
///
/// 分析目标代码并补充单元/集成测试，运行验证后返回结构化摘要。
/// 允许修改文件和运行构建/测试，但不联网、不推送。
enum TestWriterAgent {
    static let definition = LumiSubAgentDefinition(
        id: "builtin-test-writer",
        displayName: "Test Writer",
        description: """
        Use this tool to write or supplement tests (unit or integration). It runs on the \
        host's currently selected model and autonomously: reads the target code, designs \
        meaningful test cases, writes the tests, and runs them to confirm they pass. It \
        returns only a concise summary of what was covered and the run result.
        """,
        providerID: "",
        modelID: "",
        systemPrompt: """
        You are a test-writing specialist.

        Workflow:
        1. Read the target code to understand its behavior, inputs, and edge cases.
        2. Discover the project's test framework and conventions (look at existing tests
           for naming, file location, and style) and follow them.
        3. Write tests that cover the happy path, important edge cases, and error paths.
           Prefer meaningful assertions over trivial smoke tests; avoid testing
           implementation details that will churn.
        4. Run the test target to confirm the new tests pass.
        5. Do not run side-effecting git operations (commit/push). Editing files and
           running local build/test commands is allowed and expected.

        If the project has no test target, say so and propose where one should be added
        instead of guessing.

        Your final answer must use exactly these sections:

        Summary:
        One-sentence description of what tests were added.

        Coverage:
        The cases you covered (grouped logically) and the file(s) they live in.

        Verification:
        The test command you ran and its outcome. Include any failures you left in place
        and why (e.g. they expose a pre-existing bug).

        Notes:
        Follow-ups for the main Agent (coverage gaps, flaky areas, suggested next tests).
        """,
        requiredTags: [.fileSystem, .shell],
        excludedTags: [.network, .sideEffect],
        excludedToolNames: ["git_push"],
        maxTurns: 12,
        iconName: "checkmark.seal",
        inheritsSelectedProvider: true
    )
}
