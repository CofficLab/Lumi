import Foundation
import LumiCoreKit
import SuperLogKit

/// Git 状态工具
public struct GitStatusTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📊"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "git_status",
        displayName: "Git Status",
        description: "Get the current status of a Git repository, including branch info and file changes. Returns structured JSON data."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Git repository path, defaults to current working directory"),
                ]),
            ]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "查看 Git 状态"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let path = arguments.string("path")

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)获取 Git 状态：\(path ?? "当前目录")")
        }

        do {
            // 验证路径是否在允许的范围内
            let validatedPath = try GitService.validatePath(path, allowedDirectories: context.allowedDirectories)

            let status = try await GitService.shared.getStatus(path: validatedPath)
            return formatStatus(status)
        } catch {
            if Self.verbose {
                GitPlugin.logger.error("\(Self.t)获取 Git 状态失败：\(error.localizedDescription)")
            }
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
