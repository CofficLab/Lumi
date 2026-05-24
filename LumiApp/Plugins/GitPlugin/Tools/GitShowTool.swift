import Foundation
import AgentToolKit

/// Git 查看 Commit 详情工具
struct GitShowTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔎"
    nonisolated static let verbose: Bool = true
    let name = "git_show"

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "查看指定 commit 的详细信息，包括作者、日期、变更文件和统计。"
        case .english:
            return "View detailed information of a specific commit, including author, date, changed files and stats."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let pathDesc: String
        let hashDesc: String
        switch language {
        case .chinese:
            pathDesc = "Git 仓库路径，默认为当前工作目录"
            hashDesc = "Commit 哈希（完整或缩写均可）"
        case .english:
            pathDesc = "Git repository path, defaults to current working directory"
            hashDesc = "Commit hash (full or abbreviated)"
        }
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": pathDesc,
                ],
                "hash": [
                    "type": "string",
                    "description": hashDesc,
                ],
            ],
            "required": ["hash"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let path = arguments["path"]?.value as? String
        guard let hash = arguments["hash"]?.value as? String else {
            throw NSError(domain: "GitShowTool", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "缺少必需的 commit 哈希参数"])
        }

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)查看 commit 详情：\(hash)")
        }

        do {
            let detail = try await GitService.shared.getCommitDetail(path: path, hash: hash)
            let changedFiles = try GitService.shared.getCommitChangedFiles(path: path, hash: hash)
            return formatDetail(detail, changedFiles: changedFiles)
        } catch {
            if Self.verbose {
                GitPlugin.logger.error("\(Self.t)获取 commit 详情失败：\(error.localizedDescription)")
            }
            return "获取 commit 详情失败：\(error.localizedDescription)"
        }
    }

    private func formatDetail(_ detail: GitCommitDetail, changedFiles: [GitChangedFile]) -> String {
        var output = "## Commit `\(detail.hash.prefix(7))`\n\n"
        output += "**信息**: \(detail.message)\n\n"
        output += "**作者**: \(detail.author) <\(detail.email)>\n\n"
        output += "**日期**: \(detail.date)\n\n"

        if !detail.body.isEmpty {
            output += "**正文**:\n\(detail.body)\n\n"
        }

        if let stats = detail.stats {
            output += "**统计**: \(stats.filesChanged) 个文件，+\(stats.insertions) 行，-\(stats.deletions) 行\n\n"
        }

        if !changedFiles.isEmpty {
            output += "### 变更文件\n"
            for file in changedFiles {
                output += "- `[\(file.changeType.displayLabel)]` \(file.path)\n"
            }
            output += "\n"
        }

        return output
    }
}
