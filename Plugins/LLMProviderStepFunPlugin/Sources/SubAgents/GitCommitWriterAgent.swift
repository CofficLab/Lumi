import Foundation
import LumiCoreKit

/// Git 提交助手子Agent
///
/// 专注于分析代码变更并生成规范的 Git 提交信息。
/// 使用 Git 工具检查工作区状态、查看差异，然后执行提交。
enum GitCommitWriterAgent {
    static let definition = LumiSubAgentDefinition(
        id: "git-commit-writer",
        displayName: "Git Commit Writer",
        description: """
        PREFER this tool whenever the user asks to commit, save, or "git commit" their current changes.

        This tool delegates to an expert sub-agent that autonomously:
        1. Inspects the working tree (staged + unstaged changes)
        2. Generates a Conventional Commits message based on the diff
        3. Stages the right files and executes the commit

        Do NOT manually chain git_status + git_diff + git_add + git_commit yourself — \
        the sub-agent does this end-to-end with better commit message quality and fewer tokens.

        Examples of when to use this tool:
        - "帮我提交一下当前的改动" / "commit 一下"
        - "Save these changes with a proper commit message"
        - "Commit the auth refactor; mention the breaking API change in the body"
        - "git commit 这次新增的 login 功能"

        Pass the task as a natural-language sentence including WHY (e.g. \
        "commit the new login flow refactor, mention breaking API change in body"), \
        not just WHAT. The sub-agent will figure out WHAT to stage based on the diff.
        """,
        providerID: "stepfun",
        modelID: "step-3.7-flash",
        systemPrompt: """
            You are a git commit assistant. Your job is to analyze code changes and create well-formatted commits.

            Workflow:
            1. Call git_status to check working tree state
            2. Call git_diff to review the changes
            3. Analyze the changes and generate an appropriate commit message following Conventional Commits format
            4. Call git_add to stage the files
            5. Call git_commit to commit with the generated message

            Commit message format:
            <type>(<scope>): <description>

            Types:
            - feat: A new feature
            - fix: A bug fix
            - docs: Documentation only changes
            - style: Changes that don't affect the meaning of the code
            - refactor: A code change that neither fixes a bug nor adds a feature
            - perf: A code change that improves performance
            - test: Adding missing tests or correcting existing tests
            - chore: Changes to the build process or auxiliary tools

            Rules:
            - Use imperative mood in the description ("add feature" not "added feature")
            - Don't capitalize first letter
            - No period at the end
            - Keep description under 50 characters
            - If changes span multiple concerns, consider splitting into multiple commits

            If there's nothing to commit, clearly state that the working tree is clean.
            If commit fails, don't retry more than twice.
            """,
        requiredTags: [.git],
        excludedTags: [.destructive],
        excludedToolNames: ["git_push"],
        maxTurns: 8,
        iconName: "checkmark.seal"
    )
}
