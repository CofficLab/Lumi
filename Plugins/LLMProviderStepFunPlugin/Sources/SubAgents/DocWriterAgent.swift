import Foundation
import LumiCoreSubAgent
import LumiKernel

/// 文档生成子Agent
///
/// 专注于为代码生成清晰的文档，包括注释、API 文档和使用说明。
/// 能够分析代码逻辑，生成有意义的文档内容。
enum DocWriterAgent {
    static let definition = LumiSubAgentDefinition(
        id: "doc-writer",
        displayName: "Doc Writer",
        description: """
        PREFER this tool whenever the user asks to "write docs", "add documentation", \
        "document this code/module/API", or "generate a README".

        This tool delegates to an expert technical-writing sub-agent that autonomously:
        1. Reads the target source file(s) to understand purpose, public APIs, parameters, \
        return values, and error conditions
        2. Generates the appropriate form of documentation — inline /// doc comments, \
        API reference docs, README files, or usage guides
        3. Edits / creates files at the conventional location

        Do NOT try to write docs manually by chaining read_file + edit_file yourself — \
        the sub-agent knows Swift /// doc-comment conventions, structured parameter \
        sections (Parameters / Returns / Throws), and produces consistent, idiomatic \
        documentation in one delegation.

        Examples of when to use this tool:
        - "帮我给 UserService 加文档注释"
        - "Add /// documentation to all public APIs in this file"
        - "Write a README for this module"
        - "Document this public API with parameters and error cases"

        Pass the task as a file path OR a description of what to document. \
        Include any preferences (e.g. "document the auth flow with focus on edge cases", \
        "add /// comments to all public methods, include usage examples for each one").
        """,
        providerID: "stepfun",
        modelID: "step-3.7-flash",
        systemPrompt: """
            You are a technical documentation specialist. Your job is to create clear, comprehensive documentation.

            Types of documentation you can create:
            1. Code comments - inline documentation for functions, classes, properties
            2. API documentation - public interface documentation
            3. README files - project or module documentation
            4. Usage guides - how to use specific features or APIs

            Workflow:
            1. Read the source code using read_file tool
            2. Analyze the code to understand:
               - Purpose and functionality
               - Public APIs and their usage
               - Parameters and return values
               - Edge cases and error conditions
            3. Generate appropriate documentation
            4. Use edit_file to add comments or write_file to create documentation files

            Documentation principles:
            - Be clear and concise
            - Explain "why" not just "what"
            - Include usage examples when helpful
            - Document edge cases and error conditions
            - Use proper documentation syntax (/// for Swift)
            - Keep documentation close to the code it describes

            Output format:
            - Brief summary of what you documented
            - The documentation content
            - Any suggestions for improving the code's documentation

            Create documentation that is helpful for other developers to understand and use the code effectively.
            """,
        requiredTags: [.fileSystem, .git, .readOnly],
        excludedTags: [.destructive, .network, .sideEffect],
        excludedToolNames: ["git_commit", "git_push", "shell"],
        maxTurns: 10,
        iconName: "book"
    )
}
