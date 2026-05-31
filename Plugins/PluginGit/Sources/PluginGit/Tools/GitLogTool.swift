import Foundation
import SuperLogKit
import AgentToolKit

/// Git 日志工具
public struct GitLogTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📜"
    public nonisolated static let verbose: Bool = true
    public let name = "git_log"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "查看 Git 提交历史。支持限制数量、查看特定分支或文件的日志。"
        case .english:
            return "View Git commit history. Supports limiting the number of commits and viewing logs for a specific branch or file."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let pathDesc: String
        let countDesc: String
        let branchDesc: String
        let fileDesc: String
        switch language {
        case .chinese:
            pathDesc = "Git 仓库路径，默认为当前工作目录"
            countDesc = "显示的提交数量，默认 10，范围 1-50"
            branchDesc = "可选，查看特定分支的日志"
            fileDesc = "可选，查看特定文件的提交历史"
        case .english:
            pathDesc = "Git repository path, defaults to current working directory"
            countDesc = "Number of commits to display, default 10, range 1-50"
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
                    "type": "integer",
                    "description": countDesc,
                    "minimum": 1,
                    "maximum": 50
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

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "查看提交历史"
    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let path = arguments["path"]?.value as? String
        let count = Self.normalizedCount(arguments["count"]?.value as? Int)
        let branch = arguments["branch"]?.value as? String
        let file = arguments["file"]?.value as? String

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)获取 Git 日志：\(path ?? "当前目录") count=\(count)")
        }

        do {
            // 验证路径是否在允许的范围内
            let validatedPath = try GitService.validatePath(path, allowedDirectories: context.allowedDirectories)
            
            let logs = try await GitService.shared.getLog(
                path: validatedPath,
                count: count,
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

    static func normalizedCount(_ rawCount: Int?) -> Int {
        min(max(rawCount ?? 10, 1), 50)
    }
}
