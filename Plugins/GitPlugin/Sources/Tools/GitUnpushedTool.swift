import Foundation
import SuperLogKit
import AgentToolKit

/// Git 未推送 Commit 查询工具
public struct GitUnpushedTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📤"
    public nonisolated static let verbose: Bool = false
    public let name = "git_unpushed"

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "查看本地有多少 commit 尚未推送到远程仓库。"
        case .english:
            return "Check how many local commits have not been pushed to the remote repository."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
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

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "查看未推送提交"
    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let path = arguments["path"]?.value as? String

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)检查未推送 commit：\(path ?? "当前目录")")
        }

        // 验证路径是否在允许的范围内
        let validatedPath = try GitService.validatePath(path, allowedDirectories: context.allowedDirectories)

        let hashes = GitService.shared.getUnpushedCommitHashes(path: validatedPath)

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
