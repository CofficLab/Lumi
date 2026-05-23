import Foundation
import AgentToolKit

/// Git 日志工具
struct GitLogTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📜"
    nonisolated static let verbose: Bool = false
    let name = "git_log"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "查看 Git 提交历史。支持限制数量、查看特定分支或文件的日志。"
        case .english:
            return "View Git commit history. Supports limiting the number of commits and viewing logs for a specific branch or file."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let pathDesc: String
        let countDesc: String
        let branchDesc: String
        let fileDesc: String
        switch language {
        case .chinese:
            pathDesc = "Git 仓库路径，默认为当前工作目录"
            countDesc = "显示的提交数量，默认 10"
            branchDesc = "可选，查看特定分支的日志"
            fileDesc = "可选，查看特定文件的提交历史"
        case .english:
            pathDesc = "Git repository path, defaults to current working directory"
            countDesc = "Number of commits to display, default 10"
            branchDesc = "Optional, view logs for a specific branch"
            fileDesc = "Optional, view commit history for a specific file"
        }
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": pathDesc
                ],
                "count": [
                    "type": "number",
                    "description": countDesc
                ],
                "branch": [
                    "type": "string",
                    "description": branchDesc
                ],
                "file": [
                    "type": "string",
                    "description": fileDesc
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
            GitPlugin.logger.info("\(Self.t)获取 Git 日志：\(path ?? "当前目录") count=\(count)")
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
            if Self.verbose {
                GitPlugin.logger.error("\(Self.t)获取 Git 日志失败：\(error.localizedDescription)")
            }
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
