import Foundation
import LumiKernel
import SuperLogKit

/// Git 查看 Commit 详情工具
public struct GitShowTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔎"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "git_show",
        displayName: "Git Show",
        description: "View detailed information of a specific commit, including author, date, changed files and stats."
    )
    public static let tags: Set<LumiToolTag> = [.git, .readOnly]

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Git repository path, defaults to current working directory"),
                ]),
                "hash": .object([
                    "type": .string("string"),
                    "description": .string("Commit hash (full or abbreviated)"),
                ]),
            ]),
            "required": .array([.string("hash")]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "查看提交详情"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let path = arguments.string("path")
        guard let hash = arguments.string("hash") else {
            throw NSError(domain: "GitShowTool", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "缺少必需的 commit 哈希参数"])
        }

        if Self.verbose {
            GitPlugin.logger.info("\(Self.t)查看 commit 详情：\(hash)")
        }

        do {
            // 验证路径是否在允许的范围内
            let validatedPath = try GitService.validatePath(path, allowedDirectories: context.allowedDirectories)

            let detail = try await GitService.shared.getCommitDetail(path: validatedPath, hash: hash)
            let changedFiles = try GitService.shared.getCommitChangedFiles(path: validatedPath, hash: hash)
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
