import Foundation
import SuperLogKit
import AgentToolKit

/// Git 差异工具
public struct GitDiffTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = false
    public let name = "git_diff"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "查看 Git 仓库的代码变更。支持查看工作区变更或暂存区变更。"
        case .english:
            return "View code changes in a Git repository. Supports working tree changes and staged changes."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let pathDesc: String
        let stagedDesc: String
        let fileDesc: String
        switch language {
        case .chinese:
            pathDesc = "Git 仓库路径，默认为当前工作目录"
            stagedDesc = "是否查看暂存区的差异，false 表示查看工作区的差异"
            fileDesc = "可选，只查看指定文件的差异"
        case .english:
            pathDesc = "Git repository path, defaults to current working directory"
            stagedDesc = "Whether to view staged changes. false means viewing working tree changes"
            fileDesc = "Optional, only view changes for the specified file"
        }
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": pathDesc
                ],
                "staged": [
                    "type": "boolean",
                    "description": stagedDesc
                ],
                "file": [
                    "type": "string",
                    "description": fileDesc
                ]
            ]
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "查看代码变更"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let path = arguments["path"]?.value as? String
        let staged = arguments["staged"]?.value as? Bool ?? false
        let file = arguments["file"]?.value as? String

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)获取 Git 差异：\(path ?? "当前目录") staged=\(staged) file=\(file ?? "all")")
        }

        do {
            // 验证路径是否在允许的范围内
            let validatedPath = try GitService.validatePath(path, allowedDirectories: context.allowedDirectories)
            
            let diff = try await GitService.shared.getDiff(
                path: validatedPath,
                staged: staged,
                file: file
            )
            return formatDiff(diff)
        } catch {
            if Self.verbose {
                GitPlugin.logger.error("\(Self.t)获取 Git 差异失败：\(error.localizedDescription)")
            }
            return "获取 Git 差异失败：\(error.localizedDescription)"
        }
    }

    private func formatDiff(_ diff: GitDiff) -> String {
        guard !diff.isEmpty else {
            return "✅ 没有变更"
        }

        var output = "## Git 变更\n\n"

        if let stats = diff.stats {
            output += "**变更统计**: \(stats.filesChanged) 个文件，+\(stats.insertions) 行，-\(stats.deletions) 行\n\n"
        }

        output += "```diff\n\(diff.content)\n```"

        return output
    }
}
