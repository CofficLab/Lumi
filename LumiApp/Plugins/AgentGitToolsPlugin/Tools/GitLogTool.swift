import Foundation
import MagicKit

/// Git 日志工具
struct GitLogTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📜"
    nonisolated static let verbose: Bool = true
    let name = "git_log"
    let description = "查看 Git 提交历史。支持限制数量、查看特定分支或文件的日志。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Git 仓库路径，默认为当前工作目录"
                ],
                "count": [
                    "type": "number",
                    "description": "显示的提交数量，默认 10"
                ],
                "branch": [
                    "type": "string",
                    "description": "可选，查看特定分支的日志"
                ],
                "file": [
                    "type": "string",
                    "description": "可选，查看特定文件的提交历史"
                ]
            ]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let path = arguments["path"]?.value as? String
        let count = arguments["count"]?.value as? Int ?? 10
        let branch = arguments["branch"]?.value as? String
        let file = arguments["file"]?.value as? String

        if Self.verbose {
            GitToolsPlugin.logger.info("\(Self.t)获取 Git 日志：\(path ?? "当前目录") count=\(count)")
        }

        do {
            let logs = try await GitService.shared.getLog(
                path: path,
                count: min(count, 50),
                branch: branch,
                file: file
            )
            return formatLog(logs)
        } catch {
            GitToolsPlugin.logger.error("\(Self.t)获取 Git 日志失败：\(error.localizedDescription)")
            return "获取 Git 日志失败：\(error.localizedDescription)"
        }
    }

    private func formatLog(_ logs: [GitCommitLog]) -> String {
        guard !logs.isEmpty else {
            return "暂无提交记录"
        }

        var output = "## Git 提交历史\n\n"

        for (index, log) in logs.enumerated() {
            let dateStr = log.date.prefix(10)
            output += "### \(index + 1). `\(log.hash.prefix(7))` - \(log.message)\n\n"
            output += "**作者**: \(log.author)\n"
            output += "**日期**: \(dateStr)\n\n"
        }

        return output
    }
}

// MARK: - Git Commit Log Model

struct GitCommitLog: Codable {
    let hash: String
    let author: String
    let email: String
    let date: String
    let message: String
}

/// Git Commit 详情模型
///
/// 包含 commit 的完整信息，包括 body、变更统计和文件列表。
struct GitCommitDetail: Codable {
    /// 完整的 commit hash
    let hash: String
    /// 作者名称
    let author: String
    /// 作者邮箱
    let email: String
    /// 提交日期（ISO 格式）
    let date: String
    /// 提交消息（subject，第一行）
    let message: String
    /// 提交正文（subject 之后的内容）
    let body: String
    /// 变更统计
    let stats: GitDiffStats?
    /// 变更文件列表
    let changedFiles: [String]
}
