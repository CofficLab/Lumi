import Foundation
import MagicKit

/// Git 状态工具
struct GitStatusTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📊"
    nonisolated static let verbose = true

    let name = "git_status"
    let description = "获取 Git 仓库的当前状态，包括分支信息、文件变更等。返回结构化的 JSON 数据。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Git 仓库路径，默认为当前工作目录",
                ],
            ],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let path = arguments["path"]?.value as? String

        if Self.verbose {
            GitToolsPlugin.logger.info("\(Self.t)获取 Git 状态：\(path ?? "当前目录")")
        }

        do {
            let status = try await GitService.shared.getStatus(path: path)
            return formatStatus(status)
        } catch {
            GitToolsPlugin.logger.error("\(Self.t)获取 Git 状态失败：\(error.localizedDescription)")
            return "获取 Git 状态失败：\(error.localizedDescription)"
        }
    }

    private func formatStatus(_ status: GitStatus) -> String {
        var output = "## Git 仓库状态\n\n"

        // 分支信息
        output += "**分支**: `\(status.branch)`\n\n"

        if let remote = status.remote {
            output += "**远程**: `\(remote)`\n\n"
        }

        // 变更文件
        if !status.modified.isEmpty {
            output += "### 修改的文件\n"
            for file in status.modified {
                output += "- `\(file)`\n"
            }
            output += "\n"
        }

        // 新增文件
        if !status.added.isEmpty {
            output += "### 新增的文件\n"
            for file in status.added {
                output += "- `\(file)`\n"
            }
            output += "\n"
        }

        // 删除文件
        if !status.deleted.isEmpty {
            output += "### 删除的文件\n"
            for file in status.deleted {
                output += "- `\(file)`\n"
            }
            output += "\n"
        }

        // 重命名文件
        if !status.renamed.isEmpty {
            output += "### 重命名的文件\n"
            for file in status.renamed {
                output += "- `\(file)`\n"
            }
            output += "\n"
        }

        // 暂存区文件
        if !status.staged.isEmpty {
            output += "### 已暂存的文件\n"
            for file in status.staged {
                output += "- `\(file)`\n"
            }
            output += "\n"
        }

        if status.modified.isEmpty && status.added.isEmpty && status.deleted.isEmpty &&
            status.renamed.isEmpty && status.staged.isEmpty {
            output += "✅ 工作区干净，无变更\n"
        }

        return output
    }
}

// MARK: - Git Status Model

struct GitStatus: Codable {
    let branch: String
    let remote: String?
    let modified: [String]
    let added: [String]
    let deleted: [String]
    let renamed: [String]
    let staged: [String]
}
