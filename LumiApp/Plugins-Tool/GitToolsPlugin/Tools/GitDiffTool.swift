import Foundation
import MagicKit

/// Git 差异工具
struct GitDiffTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose = true

    let name = "git_diff"
    let description = "查看 Git 仓库的代码变更。支持查看工作区变更或暂存区变更。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Git 仓库路径，默认为当前工作目录"
                ],
                "staged": [
                    "type": "boolean",
                    "description": "是否查看暂存区的差异，false 表示查看工作区的差异"
                ],
                "file": [
                    "type": "string",
                    "description": "可选，只查看指定文件的差异"
                ]
            ]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel? {
        // 只读操作，低风险
        return .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let path = arguments["path"]?.value as? String
        let staged = arguments["staged"]?.value as? Bool ?? false
        let file = arguments["file"]?.value as? String

        if Self.verbose {
            GitToolsPlugin.logger.info("\(Self.t)获取 Git 差异：\(path ?? "当前目录") staged=\(staged) file=\(file ?? "all")")
        }

        do {
            let diff = try await GitService.shared.getDiff(
                path: path,
                staged: staged,
                file: file
            )
            return formatDiff(diff)
        } catch {
            GitToolsPlugin.logger.error("\(Self.t)获取 Git 差异失败：\(error.localizedDescription)")
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

// MARK: - Git Diff Model

struct GitDiff: Codable {
    let content: String
    let stats: GitDiffStats?

    var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct GitDiffStats: Codable {
    let filesChanged: Int
    let insertions: Int
    let deletions: Int
}
