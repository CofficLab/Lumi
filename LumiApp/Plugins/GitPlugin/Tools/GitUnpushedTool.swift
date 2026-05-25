import Foundation
import AgentToolKit

/// Git 未推送 Commit 查询工具
struct GitUnpushedTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📤"
    nonisolated static let verbose: Bool = true
    let name = "git_unpushed"

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "查看本地有多少 commit 尚未推送到远程仓库。"
        case .english:
            return "Check how many local commits have not been pushed to the remote repository."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let pathDesc: String
        switch language {
        case .chinese:
            pathDesc = "Git 仓库路径，默认为当前工作目录"
        case .english:
            pathDesc = "Git repository path, defaults to current working directory"
        }
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": pathDesc,
                ],
            ],
        ]
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "查看未推送提交"
    }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let path = arguments["path"]?.value as? String

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)检查未推送 commit：\(path ?? "当前目录")")
        }

        let hashes = GitService.shared.getUnpushedCommitHashes(path: path)

        return formatResult(hashes)
    }

    private func formatResult(_ hashes: [String]) -> String {
        guard !hashes.isEmpty else {
            return "✅ 所有 commit 都已推送到远程"
        }

        var output = "## 未推送的 Commit\n\n"
        output += "共有 **\(hashes.count)** 个 commit 未推送到远程：\n\n"
        for hash in hashes {
            output += "- `\(hash.prefix(7))`\n"
        }
        output += "\n💡 使用 `git push` 推送到远程"

        return output
    }
}
