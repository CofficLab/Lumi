import Foundation
import LumiCoreKit

/// 测试编写子Agent
///
/// 专注于为代码编写高质量的单元测试。
/// 能够分析代码结构，生成测试用例，并使用工具写入测试文件。
enum TestWriterAgent {
    static let definition = LumiSubAgentDefinition(
        id: "test-writer",
        displayName: "Test Writer",
        description: """
        PREFER this tool whenever the user asks to "write tests", "add unit tests", \
        "add test cases", or "test this code/function/module".

        This tool delegates to an expert sub-agent that autonomously:
        1. Reads the target source file(s) to understand the public API and contracts
        2. Identifies edge cases, boundary conditions, and error scenarios
        3. Writes a complete Swift Testing test file following project conventions \
        (@Test attributes, naming conventions, appropriate #expect / #require)
        4. Saves the test file at the conventional location

        Do NOT try to write tests manually by chaining read_file + write_file yourself — \
        the sub-agent knows Swift Testing conventions, project structure, and produces \
        a complete, well-organized test file in one delegation.

        Examples of when to use this tool:
        - "给 UserService 写个单元测试"
        - "Add unit tests for the new login function"
        - "Help me cover this module with tests"
        - "为这个 ViewModel 加几个 test case"

        Pass the task as a file path OR a short description of what needs testing. \
        Include any context about the test environment, mocks needed, or specific \
        scenarios to cover (e.g. "write tests for the new auth flow, cover happy path, \
        expired token, and missing API key").
        """,
        providerID: "stepfun",
        modelID: "step-3.7-flash",
        systemPrompt: """
            You are a test engineering specialist. Your job is to write comprehensive unit tests.

            Workflow:
            1. Read the source code using read_file tool
            2. Analyze the code to identify:
               - Public APIs that need testing
               - Edge cases and boundary conditions
               - Error scenarios
               - Happy paths
            3. Write tests following Swift Testing framework conventions
            4. Use write_file to create the test file

            Test structure:
            - Use @Test attributes
            - Follow naming: test_<functionName>_<scenario>
            - Test both success and failure cases
            - Include edge cases (empty input, nil, boundary values)
            - Use appropriate assertions (#expect, #require)

            Best practices:
            - One assertion per test when possible
            - Clear test names that describe the scenario
            - Setup/teardown when needed
            - Mock external dependencies
            - Avoid testing implementation details

            Output format:
            - Brief summary of what you're testing
            - The complete test file content
            - Explanation of test coverage

            Write tests that are maintainable, readable, and provide confidence in the code.
            """,
        requiredTags: [.fileSystem, .git, .readOnly],
        excludedTags: [.destructive, .network, .sideEffect],
        excludedToolNames: ["git_commit", "git_push", "shell"],
        maxTurns: 12,
        iconName: "checkmark.circle"
    )
}
