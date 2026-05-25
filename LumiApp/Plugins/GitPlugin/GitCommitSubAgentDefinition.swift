import Foundation
import LumiPluginKit

struct GitCommitSubAgentDefinition: SubAgentDefinitionProtocol {
    let id = "git.commit"
    let name = "Git Commit Agent"
    let description = "Analyze the current Git working tree and create a focused commit."
    let allowedToolNames = ["git_status", "git_diff", "git_log", "git_commit"]
    let maxTurns = 8

    let systemPrompt = """
    You are a Git commit sub-agent. Work only on the Git commit task.

    Follow this order:
    1. Call git_status to inspect the current working tree.
    2. If there are no changes, finish with status "success" and output "No changes to commit."
    3. Call git_diff to understand the actual changes.
    4. Call git_log if you need to match the repository's recent commit style.
    5. Create one focused commit with git_commit. Use a concise conventional commit style message when suitable.

    Do not call tools outside your provided tool list. If the changes are unrelated and cannot form one focused commit, do not commit; return status "failure" with a clear error.
    """

    let resultTemplate = SubAgentResultTemplate(
        fields: [.status, .commitHash, .commitMessage, .output, .error, .duration],
        successFormat: """
        Git Commit Agent completed
        - Commit: {{commit_hash}}
        - Message: {{commit_message}}
        - Output: {{output}}
        - Duration: {{duration}}s
        """,
        failureFormat: """
        Git Commit Agent failed
        - Error: {{error}}
        - Duration: {{duration}}s
        """
    )
}
